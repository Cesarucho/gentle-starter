#!/usr/bin/env python3
"""Bounded directory creation and modes using the applied manifest, never live Compose."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'Duplicate policy key: {key}')
        result[key] = value
    return result


def relative(value):
    return (isinstance(value, str) and bool(value) and '\0' not in value
            and all(part not in {'', '.', '..'} for part in value.split('/')))


def overlaps(left, right):
    return left == right or left.startswith(right + '/') or right.startswith(left + '/')


def validate_policy(policy):
    if (not isinstance(policy, dict) or set(policy) != {'version', 'rules'}
            or type(policy['version']) is not int or policy['version'] != 1
            or not isinstance(policy['rules'], list)):
        raise ValueError('Expected runtime directory policy version 1 and rules array')
    rules = policy['rules']
    for index, rule in enumerate(rules):
        if (not isinstance(rule, dict) or set(rule) not in ({'root', 'path', 'mode', 'missing'},
                                                         {'root', 'path', 'mode', 'missing', 'when'})
                or not relative(rule['path']) or not relative(rule['root'])
                or (rule['root'] != 'workspace' and not rule['root'].startswith('.env.d/'))
                or not isinstance(rule['mode'], str)
                or re.fullmatch(r'0[0-7]{3}', rule['mode']) is None
                or rule['missing'] not in ('skip', 'create')):
            raise ValueError(f'Invalid exact-directory rule {index}')
        if 'when' in rule:
            condition = rule['when']
            if (not isinstance(condition, dict) or set(condition) != {'enabled_installer'}
                    or not isinstance(condition['enabled_installer'], str)
                    or re.fullmatch(r'[0-9]{4}-[a-z0-9-]+\.sh', condition['enabled_installer']) is None
                    or rule['root'] == 'workspace'):
                raise ValueError(f'Invalid optional-tool condition {index}')
        for previous in rules[:index]:
            if previous['root'] != rule['root']:
                continue
            if previous['path'] == rule['path']:
                raise ValueError('Duplicate directory rules')
            for parent, child in [(previous, rule), (rule, previous)]:
                if child['path'].startswith(parent['path'] + '/') and int(parent['mode'], 8) & 0o022:
                    raise ValueError('Configured parent would be an insecure writable ancestor')
    return rules


def applicable_rules(workspace, rules):
    """Use the shared canonical alias API, independently of Compose selection."""
    install = Path(workspace) / '.devcontainer/install'
    active = {}
    for rule in rules:
        if 'when' not in rule:
            continue
        name = rule['when']['enabled_installer']
        if name in active:
            continue
        script = install / 'available' / name
        if (not script.is_file() or script.is_symlink()
                or script.resolve().parent != (install / 'available').resolve()):
            raise ValueError(f'Unknown canonical installer: {name}')
        result = subprocess.run(['bash', '-c',
                                 'source "$1/lib/activation.sh"; devcontainer_active_aliases "$1" "$2"',
                                 '_', str(install), str(script)], capture_output=True, text=True, check=True)
        active[name] = bool(result.stdout.strip())
    return [rule for rule in rules if 'when' not in rule or active[rule['when']['enabled_installer']]]


def validate_boundaries(workspace, rules, volumes):
    """Preserve cross-root safety even when a caller applies only a subset."""
    roots = {'workspace': str(workspace)}
    mounts = []
    sources = set()
    for volume in volumes:
        mounts.append(volume['target'])
        if volume.get('managed') is True:
            source = volume['source']
            if source in sources:
                raise ValueError(f'Ambiguous managed source: {source}')
            sources.add(source)
            mounts.append(str(workspace / source))
            if volume.get('type') == 'bind' and volume.get('read_only') is False:
                roots[source] = volume['target']
    destinations = []
    for rule in rules:
        owner = rule['root']
        if owner not in roots:
            raise ValueError(f'Root is not a writable managed directory bind: {owner}')
        destination = roots[owner] + '/' + rule['path']
        source = str((workspace if owner == 'workspace' else workspace / owner) / rule['path'])
        if any(mount != roots[owner] and overlaps(destination, mount) for mount in mounts):
            raise ValueError(f'Rule overlaps a mount boundary: {destination}')
        if any(other_owner != owner and (overlaps(destination, other) or overlaps(source, other_source))
               for other_owner, other, other_source in destinations):
            raise ValueError('Overlapping resolved or source-side directory rules')
        destinations.append((owner, destination, source))


class Plan:
    """Pin existing directories and plan explicit missing nodes before mutation."""

    def __init__(self, workspace, rules: list[dict], volumes, deferred_roots=(), validation_only=False):
        self.fds = []
        self.edges = []
        self.repairs = []
        self.nodes = {}
        self.creations = []
        self.ancestors = []
        self.exclusions = set()
        self.workspace = Path(os.path.abspath(workspace))
        self.deferred_roots = set(deferred_roots)
        self.deferred_fds = set()
        self.validation_only = validation_only
        try:
            roots = {'workspace': str(self.workspace)}
            mount_paths = []
            sources = set()
            for volume in volumes:
                target = volume['target']
                mount_paths.append(target)
                if Path(target).is_relative_to(self.workspace):
                    self.exclusions.add(target)
                if volume.get('managed') is True:
                    source = volume['source']
                    source_path = str(self.workspace / source)
                    mount_paths.append(source_path)
                    self.exclusions.add(source_path)
                    if source in sources:
                        raise ValueError(f'Ambiguous managed source: {source}')
                    sources.add(source)
                    if volume.get('type') == 'bind' and volume.get('read_only') is False:
                        roots[source] = target
            destinations = []
            source_destinations = []
            declarations = {(rule['root'], rule['path']): rule for rule in rules}
            for rule in sorted(rules, key=lambda rule: rule['path'].count('/')):
                if rule['root'] not in roots:
                    raise ValueError(f'Root is not a writable managed directory bind: {rule["root"]}')
                root = roots[rule['root']]
                destination = root + '/' + rule['path']
                source_root = self.workspace if rule['root'] == 'workspace' else self.workspace / rule['root']
                source_destination = str(source_root / rule['path'])
                if any(overlaps(source_destination, other) and owner != rule['root']
                       for owner, other in source_destinations):
                    raise ValueError('Overlapping source-side directory rules')
                source_destinations.append((rule['root'], source_destination))
                # No rule may traverse another mount or use the workspace as a
                # back door to a managed source, read-only bind or external bind.
                for mount in mount_paths:
                    if mount != root and overlaps(destination, mount):
                        raise ValueError(f'Rule overlaps a mount boundary: {destination}')
                if any(overlaps(destination, other) and owner != rule['root']
                       for owner, other in destinations):
                    raise ValueError('Overlapping resolved directory rules')
                destinations.append((rule['root'], destination))
                if Path(destination).is_relative_to(self.workspace):
                    self.exclusions.add(destination)
                # Protect source-side policy trees even if Git does not ignore them.
                if rule['root'] != 'workspace':
                    self.exclusions.add(str(self.workspace / rule['root'] / rule['path']))
                root_fd = self.open_root(root, root_ancestor=rule['root'] not in self.deferred_roots)
                node = self.open_relative(root_fd, rule, root, declarations)
                target_fd = node['fd']
                if target_fd is not None or node['create']:
                    mode = int(rule['mode'], 8)
                    needs_change = target_fd is None or stat.S_IMODE(os.fstat(target_fd).st_mode) != mode
                    if needs_change and target_fd is not None and not validation_only:
                        info = os.fstat(target_fd)
                        device, inode = info.st_dev, info.st_ino
                        target_fd = self.open_dir(node['name'], node['parent']['fd'], metadata_only=False)
                        info = os.fstat(target_fd)
                        if (info.st_dev, info.st_ino) != (device, inode):
                            raise ValueError(f'Directory changed while opening repair descriptor: {destination}')
                        node['fd'] = target_fd
                    self.repairs.append((node, mode, destination, needs_change))
        except BaseException:
            self.close()
            raise

    def open_dir(self, name, parent=None, metadata_only=True):
        # O_PATH needs no read permission and cannot read authority contents.
        # Only a leaf needing fchmod is reopened read-only, with the same no-follow gate.
        access = os.O_PATH if metadata_only else os.O_RDONLY
        fd = os.open(name, access | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
                     dir_fd=parent)
        self.fds.append(fd)
        info = os.fstat(fd)
        if parent is not None:
            self.edges.append((parent, name, fd, info.st_dev, info.st_ino))
        return fd

    def check(self, fd, label, ancestor=True, system=False):
        info = os.fstat(fd)
        owners = {os.getuid(), 0} if system else {os.getuid()}
        if not stat.S_ISDIR(info.st_mode) or info.st_uid not in owners:
            raise ValueError(f'Unexpected directory owner or type: {label}')
        # Root-owned sticky system directories (e.g. /tmp) protect owned entries.
        sticky_system = system and info.st_uid == 0 and info.st_mode & stat.S_ISVTX
        if ancestor and info.st_mode & 0o022 and not sticky_system:
            raise ValueError(f'Insecure writable ancestor: {label}')

    def open_root(self, root, root_ancestor=True):
        fd = self.open_dir('/')
        self.check(fd, '/', system=True)
        self.ancestors.append((fd, '/', True))
        parts = Path(root).parts[1:]
        for index, part in enumerate(parts):
            fd = self.open_dir(part, fd)
            self.check(fd, root, ancestor=root_ancestor or index < len(parts) - 1,
                       system=index < len(parts) - 1)
            self.ancestors.append((fd, root, index < len(parts) - 1))
        if not root_ancestor:
            self.deferred_fds.add(fd)
        return fd

    def open_relative(self, fd, rule, root, declarations):
        path = rule['path']
        parts = path.split('/')
        parent = {'fd': fd}
        for index, part in enumerate(parts):
            prefix = '/'.join(parts[:index + 1])
            key = (rule['root'], prefix)
            label = root + '/' + prefix
            if key not in self.nodes:
                fd = None
                if parent['fd'] is not None:
                    try:
                        fd = self.open_dir(part, parent['fd'])
                    except FileNotFoundError:
                        pass  # Only ENOENT is absent; all other errors propagate.
                    except NotADirectoryError as error:
                        if root == str(self.workspace) and part == '.git' and index == 0:
                            raise ValueError('File or symlink .git is unsupported; no external metadata repair') from error
                        raise
                declaration = declarations.get(key)
                create = fd is None and declaration is not None and declaration['missing'] == 'create'
                node = {'fd': fd, 'parent': parent, 'name': part, 'label': label, 'create': create}
                self.nodes[key] = node
                if create:
                    self.creations.append(node)
                if fd is None:
                    # Protect the first absent component, not just the declared leaf.
                    if Path(label).is_relative_to(self.workspace):
                        self.exclusions.add(label)
                    source = self.workspace if rule['root'] == 'workspace' else self.workspace / rule['root']
                    self.exclusions.add(str(source / prefix))
            node = self.nodes[key]
            if node['fd'] is None and rule['missing'] == 'create' and not node['create']:
                raise ValueError(f'Missing intermediate requires an explicit create rule: {label}')
            if node['fd'] is not None:
                self.check(node['fd'], label, ancestor=index < len(parts) - 1)
                if index < len(parts) - 1:
                    self.ancestors.append((node['fd'], label, False))
            parent = node
        return parent

    def verify_edges(self, edges=None):
        for parent, name, fd, device, inode in self.edges if edges is None else edges:
            info = os.stat(name, dir_fd=parent, follow_symlinks=False)
            if (info.st_dev, info.st_ino) != (device, inode) or not stat.S_ISDIR(info.st_mode):
                raise ValueError(f'Directory changed after validation: {name}')

    def verify_ancestors(self):
        for fd, label, system in self.ancestors:
            self.check(fd, label, ancestor=fd not in self.deferred_fds, system=system)

    def verify_safety(self):
        """Recheck the entire dry plan without enforcing unrelated exact modes."""
        self.verify_edges()
        self.verify_ancestors()
        for node in self.nodes.values():
            if node['fd'] is not None:
                self.check(node['fd'], node['label'], ancestor=False)
            elif node['parent']['fd'] is not None:
                try:
                    os.stat(node['name'], dir_fd=node['parent']['fd'], follow_symlinks=False)
                except FileNotFoundError:
                    continue
                raise ValueError(f'Directory appeared after validation: {node["label"]}')

    def verify_lineage(self, fd):
        # Only this path: unrelated already-finalized 0000 parents need no traversal.
        by_fd = {edge[2]: edge for edge in self.edges}
        leaf = True
        while fd in by_fd:
            edge = by_fd[fd]
            self.verify_edges([edge])
            self.check(fd, edge[1], ancestor=not leaf,
                       system=any(item[0] == fd and item[2] for item in self.ancestors))
            leaf = False
            fd = edge[0]
        self.check(fd, '/', system=True)

    def apply(self):
        if self.validation_only or self.deferred_roots:
            raise ValueError('Deferred root privacy is validation-only; installer recovery must precede apply')
        self.verify_edges()
        self.verify_ancestors()
        for node, mode, label, modifiable in self.repairs:
            if node['fd'] is None:
                continue
            self.check(node['fd'], label, ancestor=False)
            if not modifiable and stat.S_IMODE(os.fstat(node['fd']).st_mode) != mode:
                raise ValueError(f'Directory mode changed after validation: {label}')
        for node in self.creations:
            self.verify_edges()
            self.verify_ancestors()
            parent = node['parent']['fd']
            self.check(parent, node['label'])
            # Never adopt an entry created concurrently; EEXIST is a failure.
            old_umask = os.umask(0o077)
            try:
                os.mkdir(node['name'], 0o700, dir_fd=parent)
            finally:
                os.umask(old_umask)
            info = os.stat(node['name'], dir_fd=parent, follow_symlinks=False)
            fd = self.open_dir(node['name'], parent, metadata_only=False)
            opened = os.fstat(fd)
            if (info.st_dev, info.st_ino) != (opened.st_dev, opened.st_ino):
                raise ValueError(f'Directory changed during creation: {node["label"]}')
            self.check(fd, node['label'])
            if stat.S_IMODE(opened.st_mode) != 0o700:
                raise ValueError(f'Created directory is not private: {node["label"]}')
            node['fd'] = fd
            self.ancestors.append((fd, node['label'], False))
        self.verify_edges()
        self.verify_ancestors()
        # Children are constructed before exact modes, including 0000, are finalized.
        for node, mode, label, modifiable in sorted(self.repairs, key=lambda item: item[2].count('/'), reverse=True):
            fd = node['fd']
            self.verify_lineage(fd)
            if stat.S_IMODE(os.fstat(fd).st_mode) != mode:
                os.fchmod(fd, mode)
            if stat.S_IMODE(os.fstat(fd).st_mode) != mode:
                raise ValueError(f'Directory mode verification failed: {label}')

    def close(self):
        for fd in reversed(self.fds):
            os.close(fd)
        self.fds.clear()

    def __enter__(self):
        return self

    def __exit__(self, *unused):
        self.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['validate', 'exclusions', 'apply'])
    parser.add_argument('workspace', type=Path)
    parser.add_argument('--root', action='append', default=[], help='Select rules by root identifier')
    parser.add_argument('--exclude-root', action='append', default=[], help='Leave a root to its specialized installer')
    parser.add_argument('--expected-root', action='append', default=[], metavar='SOURCE=TARGET',
                        help='Require an applicable writable managed root mapping')
    parser.add_argument('--defer-root', action='append', default=[],
                        help='Dry-run only: validate owned root while installer-owned privacy recovery is pending')
    args = parser.parse_args()
    workspace = Path(os.path.abspath(args.workspace))
    spec = importlib.util.spec_from_file_location('applied_manifest',
                                                workspace / '.taskfiles/scripts/compose-manifest.py')
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    manifest = module.load_manifest(workspace, runtime=True)
    policy = json.loads((workspace / '.devcontainer/config/runtime-directory-permissions.json').read_text(),
                        object_pairs_hook=unique_object)
    rules = validate_policy(policy)
    known = {rule['root'] for rule in rules}
    if any(root not in known for root in args.root + args.exclude_root + args.defer_root):
        raise ValueError('Unknown policy root selector')
    if args.command == 'apply' and args.defer_root:
        raise ValueError('Deferred root privacy is validation-only')
    if 'workspace' in args.defer_root:
        raise ValueError('Workspace privacy cannot be deferred')
    rules = applicable_rules(workspace, rules)
    applicable = {rule['root'] for rule in rules}
    for expectation in args.expected_root:
        source, separator, target = expectation.partition('=')
        targets = [volume['target'] for volume in manifest['volumes']
                   if volume.get('managed') is True and volume.get('type') == 'bind'
                   and volume.get('read_only') is False and volume['source'] == source]
        if not separator or source not in applicable or targets != [target]:
            raise ValueError(f'Expected root must match the validated applied target: {expectation}')
    validate_boundaries(workspace, rules, manifest['volumes'])
    # Selection narrows mutation, never filesystem validation. Keep the whole
    # applicable plan pinned and metadata-only, including unreadable unselected
    # leaves, and recheck it immediately before selected application.
    with Plan(workspace, rules, manifest['volumes'], args.defer_root, validation_only=True) as whole:
        whole.verify_safety()
        selected = [rule for rule in rules if (not args.root or rule['root'] in args.root)
                    and rule['root'] not in args.exclude_root]
        if args.command == 'apply':
            with Plan(workspace, selected, manifest['volumes']) as plan:
                whole.verify_safety()
                plan.apply()
        elif args.command == 'exclusions':
            # Protect all applicable subtrees, even when mutation is scoped.
            for path in sorted(whole.exclusions):
                sys.stdout.buffer.write(os.fsencode(path) + b'\0')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError) as error:
        print(f'[runtime-permissions:error] {error}', file=sys.stderr)
        sys.exit(1)
