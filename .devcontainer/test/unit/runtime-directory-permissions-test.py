#!/usr/bin/env python3
"""Isolated exact-directory policy contracts; never inspect real authority state."""
import errno
import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import shutil
import shlex
import tempfile
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[3]
HELPER = REPO / '.devcontainer/lifecycle/runtime-directory-permissions.py'
spec = importlib.util.spec_from_file_location('permissions', HELPER)
assert spec is not None and spec.loader is not None
permissions = importlib.util.module_from_spec(spec)
spec.loader.exec_module(permissions)


class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.workspace = Path(self.temp.name) / 'workspace'
        self.workspace.mkdir()
        self.target = self.workspace / '.git/gentle-ai/review-mode/rar-authority'
        self.target.mkdir(parents=True)
        self.rule = {'root': 'workspace', 'path': '.git/gentle-ai/review-mode/rar-authority',
                     'mode': '0700', 'missing': 'skip'}

    def rules(self, *rules):
        return permissions.validate_policy({'version': 1, 'rules': list(rules or [self.rule])})

    def apply(self, rules=None, volumes=()):
        with permissions.Plan(self.workspace, self.rules() if rules is None else rules, volumes) as plan:
            plan.apply()

    def mode(self, path):
        return stat.S_IMODE(path.stat().st_mode)

    def test_exact_private_repair_idempotence_preserves_descendants(self):
        child = self.target / 'child'
        child.mkdir(mode=0o711)
        payload = child / 'sentinel'
        payload.write_text('unchanged')
        payload.chmod(0o640)
        before = (child.stat(), payload.stat())
        self.apply()
        self.apply()
        self.assertEqual(self.mode(self.target), 0o700)
        self.assertEqual((child.stat(), payload.stat()), before)
        self.assertEqual(payload.read_text(), 'unchanged')

    def test_missing_is_skipped_without_creation_and_still_excluded(self):
        rule = dict(self.rule, path='absent/subtree')
        with permissions.Plan(self.workspace, self.rules(rule), []) as plan:
            self.assertIn(str(self.workspace / rule['path']), plan.exclusions)
            plan.apply()
        self.assertFalse((self.workspace / 'absent').exists())

    def test_automatic_policy_is_creation_only(self):
        config = (REPO / '.devcontainer/devcontainer.json').read_text()
        self.assertIn('"postCreateCommand": "bash ${containerWorkspaceFolder}/.devcontainer/setup.sh"', config)
        self.assertNotIn('"postStartCommand"', config)
        tasks = (REPO / '.taskfiles/devcontainer.yml').read_text()
        restart = tasks.split('\n  restart:\n', 1)[1].split('\n  recreate:\n', 1)[0]
        self.assertNotIn('runtime-directory-permissions', restart)
        self.assertNotIn('docker exec', restart)
        self.assertNotIn('. .devcontainer/.env', restart)

    def test_directory_created_after_missing_skip_waits_for_next_application(self):
        rule = dict(self.rule, path='later')
        self.apply(self.rules(rule))
        later = self.workspace / 'later'
        self.assertFalse(later.exists())
        later.mkdir(mode=0o755)
        self.assertEqual(self.mode(later), 0o755)
        self.apply(self.rules(rule))
        self.assertEqual(self.mode(later), 0o700)

    def test_zero_mode_is_accepted_applied_and_idempotent(self):
        rule = dict(self.rule, mode='0000')
        self.addCleanup(self.target.chmod, 0o700)
        self.apply(self.rules(rule))
        self.apply(self.rules(rule))
        self.assertEqual(self.mode(self.target), 0)

    def test_ancestor_writable_mode_after_preflight_allows_selected_repair(self):
        for mode in [0o775, 0o777]:
            with self.subTest(mode=oct(mode)):
                self.target.parent.chmod(0o755)
                self.target.chmod(0o755)
                with permissions.Plan(self.workspace, self.rules(), []) as plan:
                    self.target.parent.chmod(mode)
                    plan.apply()
                self.assertEqual(self.mode(self.target.parent), mode)
                self.assertEqual(self.mode(self.target), 0o700)

    def test_schema_paths_and_modes_fail_closed(self):
        for key, values in {'path': ['', '.', '..', '/absolute', 'a/../b', 'a//b', 'a/', 'a\0b'],
                            'mode': [700, '8888', '1700', '0o700', '700', '0755 '],
                            'root': ['external', '../.env.d', '.env.d'],
                            'missing': ['error', '', None]}.items():
            for value in values:
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    self.rules(dict(self.rule, **{key: value}))
        for mode in ['0000', '0001', '0755', '0777']:
            self.rules(dict(self.rule, mode=mode))
        for policy in [{'rules': []}, {'version': True, 'rules': []},
                       {'version': 1, 'rules': [], 'extra': 1}]:
            with self.assertRaises(ValueError):
                permissions.validate_policy(policy)

    def test_duplicate_and_unsafe_parent_rules_rejected(self):
        for other in [self.rule, dict(self.rule, path='.git', mode='0777')]:
            with self.assertRaises(ValueError):
                self.rules(self.rule, other)

    def conditional_fixture(self):
        install = self.workspace / '.devcontainer/install'
        for group in ['available', '03-enabled', 'lib']:
            (install / group).mkdir(parents=True, exist_ok=True)
        shutil.copyfile(REPO / '.devcontainer/install/lib/activation.sh', install / 'lib/activation.sh')
        (install / 'available/4010-tool-ssh-server.sh').write_text('# fixture installer\n')
        return install, dict(self.rule, root='.env.d/.ssh-server', path='ssh', missing='create',
                             when={'enabled_installer': '4010-tool-ssh-server.sh'})

    def assert_valid_policy_text(self, text):
        policy = json.loads(text, object_pairs_hook=permissions.unique_object)
        rules = permissions.validate_policy(policy)
        self.assertEqual(rules, policy['rules'])

    def test_shipped_policy_has_valid_schema(self):
        self.assert_valid_policy_text(
            (REPO / '.devcontainer/config/runtime-directory-permissions.json').read_text())

    def test_shipped_policy_validation_accepts_configurable_directory_rules(self):
        base = dict(self.rule, path='fixture-directory')
        added = dict(base, path='another-directory.json', mode='0750', missing='create')
        variants = {
            'baseline': [base],
            'added': [base, added],
            'removed': [],
            'changed': [dict(base, path='renamed-directory', mode='0710', missing='create')],
        }
        for change, rules in variants.items():
            with self.subTest(change=change):
                policy = {'version': 1, 'rules': rules}
                # Prove these are valid inputs before exercising the shipped-policy check.
                self.assertEqual(permissions.validate_policy(policy), rules)
                self.assert_valid_policy_text(json.dumps(policy))

    def test_regular_file_target_rejected_before_any_mode_changes(self):
        payload = self.workspace / 'generation.json'
        payload.write_text('fixture payload')
        before = (self.target.stat(), payload.stat())
        for missing in ['skip', 'create']:
            with self.subTest(missing=missing):
                rules = self.rules(self.rule, dict(self.rule, path=payload.name,
                                                  mode='0600', missing=missing))
                with self.assertRaises(NotADirectoryError) as rejected:
                    self.apply(rules)
                self.assertEqual(rejected.exception.errno, errno.ENOTDIR)
                self.assertEqual((self.target.stat(), payload.stat()), before)
                self.assertEqual(payload.read_text(), 'fixture payload')

    def test_json_named_directory_is_a_valid_directory_target(self):
        directory = self.workspace / 'directory.json'
        directory.mkdir(mode=0o755)
        self.apply(self.rules(dict(self.rule, path=directory.name)))
        self.assertEqual(self.mode(directory), 0o700)

    def authority_rules(self):
        return self.rules(*(dict(self.rule, path=self.rule['path'] + suffix)
                            for suffix in ['', '/v1', '/v1/rdd-mode']))

    def test_nested_authority_skip_never_creates_missing_directories(self):
        rules = self.authority_rules()
        for existing_count in range(4):
            with self.subTest(existing_count=existing_count):
                workspace = Path(self.temp.name) / f'nested-{existing_count}'
                (workspace / '.git/gentle-ai/review-mode').mkdir(parents=True)
                directories = [workspace / rule['path'] for rule in rules]
                for directory in directories[:existing_count]:
                    directory.mkdir(mode=0o755)
                for _ in range(2):
                    with permissions.Plan(workspace, rules, []) as plan:
                        for directory in directories:
                            self.assertIn(str(directory), plan.exclusions)
                        self.assertEqual(plan.creations, [])
                        plan.apply()
                    for directory in directories[:existing_count]:
                        self.assertEqual(self.mode(directory), 0o700)
                    for directory in directories[existing_count:]:
                        self.assertFalse(directory.exists())

    def test_nested_authority_writable_ancestors_receive_selected_exact_modes(self):
        version = self.target / 'v1'
        version.mkdir(mode=0o755)
        nested = version / 'rdd-mode'
        nested.mkdir(mode=0o755)
        for mode in [0o775, 0o777]:
            with self.subTest(mode=oct(mode)):
                for directory in [self.target, version, nested]:
                    directory.chmod(mode)
                self.apply(self.authority_rules())
                self.assertEqual([self.mode(directory) for directory in [self.target, version, nested]],
                                 [0o700, 0o700, 0o700])

    def test_conditional_rule_uses_canonical_alias_not_mount_selection(self):
        install, rule = self.conditional_fixture()
        rules = self.rules(rule)
        self.assertEqual(permissions.applicable_rules(self.workspace, rules), [])
        (install / '03-enabled/custom.sh').symlink_to('../available/4010-tool-ssh-server.sh')
        self.assertEqual(permissions.applicable_rules(self.workspace, rules), rules)
        with self.assertRaises(ValueError):
            self.apply(permissions.applicable_rules(self.workspace, rules))
        self.assertFalse((self.workspace / '.env.d').exists())

    def test_condition_typos_and_unknown_installers_fail_even_disabled(self):
        _, rule = self.conditional_fixture()
        for condition in [None, {}, {'enabled_instaler': '4010-tool-ssh-server.sh'},
                          {'enabled_installer': '../4010-tool-ssh-server.sh'},
                          {'enabled_installer': True},
                          {'enabled_installer': '4010-tool-ssh-server.sh', 'extra': True}]:
            with self.subTest(condition=condition), self.assertRaises(ValueError):
                self.rules(dict(rule, when=condition))
        rules = self.rules(dict(rule, when={'enabled_installer': '9999-tool-typo.sh'}))
        with self.assertRaises(ValueError):
            permissions.applicable_rules(self.workspace, rules)

    def test_conditional_duplicates_are_rejected_before_applicability(self):
        _, rule = self.conditional_fixture()
        with self.assertRaises(ValueError):
            self.rules(rule, {key: value for key, value in rule.items() if key != 'when'})

    def applied_cli_fixture(self, volumes):
        install, rule = self.conditional_fixture()
        scripts = self.workspace / '.taskfiles/scripts'
        scripts.mkdir(parents=True)
        shutil.copyfile(REPO / '.taskfiles/scripts/compose-manifest.py', scripts / 'compose-manifest.py')
        spec = importlib.util.spec_from_file_location('conditional_manifest', scripts / 'compose-manifest.py')
        assert spec is not None and spec.loader is not None
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        manifest = module.project_manifest(self.workspace, 'container-svc',
                                           [self.workspace / '.devcontainer/docker-compose.yml'],
                                           {'volumes': volumes or [{'type': 'bind',
                                                                    'source': str(self.workspace / '.env.d/.other'),
                                                                    'target': '/fixture/state',
                                                                    'bind': {'create_host_path': False}}]})
        (self.workspace / module.MANIFEST).write_text(json.dumps(manifest))
        config = self.workspace / '.devcontainer/config'
        config.mkdir()
        (config / 'runtime-directory-permissions.json').write_text(json.dumps(
            {'version': 1, 'rules': [self.rule, rule]}))
        self.identity = manifest['id']
        return install, rule

    def cli(self, command, *arguments):
        return subprocess.run(['python3', str(HELPER), command, str(self.workspace), *arguments],
                              env=dict(os.environ, DEVCONTAINER_BIND_MANIFEST_ID=self.identity),
                              capture_output=True, text=True)

    def test_real_applied_conditional_disabled_mount_and_no_mount_are_not_applicable(self):
        root = Path(self.temp.name) / 'absent-target'
        self.applied_cli_fixture([{'type': 'bind', 'source': str(self.workspace / '.env.d/.ssh-server'),
                                   'target': str(root), 'bind': {'create_host_path': False}}])
        result = self.cli('apply')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(root.exists())
        self.assertEqual(self.mode(self.target), 0o700)

    def test_real_applied_enabled_without_mount_fails_before_authority_mutation(self):
        install, _ = self.applied_cli_fixture([])
        result = self.cli('validate')
        self.assertEqual(result.returncode, 0, result.stderr)
        (install / '03-enabled/custom.sh').symlink_to('../available/4010-tool-ssh-server.sh')
        result = self.cli('apply')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('writable managed directory bind', result.stderr)
        self.assertEqual(self.mode(self.target), 0o755)

    def test_real_applied_enabled_invalid_targets_fail_before_mutation(self):
        root = Path(self.temp.name) / 'absent-target'
        install, _ = self.applied_cli_fixture([{'type': 'bind', 'source': str(self.workspace / '.env.d/.ssh-server'),
                                              'target': str(root), 'bind': {'create_host_path': False}}])
        (install / '03-enabled/custom.sh').symlink_to('../available/4010-tool-ssh-server.sh')
        for shape in ['absent', 'file', 'symlink']:
            if shape == 'file':
                root.write_text('not a directory')
            elif shape == 'symlink':
                root.rename(root.with_name('file-original'))
                root.symlink_to(self.target, target_is_directory=True)
            result = self.cli('apply')
            self.assertNotEqual(result.returncode, 0, shape)
            self.assertEqual(self.mode(self.target), 0o755)

    def test_real_applied_deferred_privacy_is_dry_only_and_subset_preserves_authority(self):
        root = Path(self.temp.name) / 'keys'
        root.mkdir()
        root.chmod(0o777)
        install, rule = self.applied_cli_fixture([{'type': 'bind', 'source': str(self.workspace / '.env.d/.ssh-server'),
                                                 'target': str(root), 'bind': {'create_host_path': False}}])
        (install / '03-enabled/custom.sh').symlink_to('../available/4010-tool-ssh-server.sh')
        expected = ['--expected-root', f'{rule["root"]}={root}']
        for command in ['validate', 'exclusions']:
            result = self.cli(command, '--defer-root', rule['root'], *expected)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.mode(root), 0o777)
        self.assertFalse((root / 'ssh').exists())
        result = self.cli('apply', '--defer-root', rule['root'])
        self.assertNotEqual(result.returncode, 0)
        result = self.cli('validate', '--root', rule['root'], '--expected-root', f'{rule["root"]}={root}/other')
        self.assertNotEqual(result.returncode, 0)
        root.chmod(0o700)  # Simulate only the specialized installer's owned-root recovery.
        result = self.cli('apply', '--root', rule['root'], *expected)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.mode(root / 'ssh'), 0o700)
        self.assertEqual(self.mode(self.target), 0o755)
        for arguments in [('--root', '.env.d/typo'), ('--defer-root', 'workspace')]:
            self.assertNotEqual(self.cli('validate', *arguments).returncode, 0)

    def test_disabled_broken_and_wrong_aliases_do_not_activate_condition(self):
        install, rule = self.conditional_fixture()
        (install / '03-enabled/broken.sh').symlink_to('/missing/4010-tool-ssh-server.sh')
        (install / '03-enabled/4010-tool-ssh-server.sh').write_text('not an alias')
        self.assertEqual(permissions.applicable_rules(self.workspace, self.rules(rule)), [])

    def test_subset_boundary_validation_preserves_cross_root_alias_safety(self):
        volumes = [{'type': 'bind', 'source': source, 'target': '/fixture/state',
                    'managed': True, 'read_only': False}
                   for source in ['.env.d/first', '.env.d/second']]
        rules = self.rules(*(dict(self.rule, root=volume['source'], path='private') for volume in volumes))
        with self.assertRaises(ValueError):
            permissions.validate_boundaries(self.workspace, rules, volumes)

    def scoped_ssh_fixture(self):
        root = Path(self.temp.name) / 'keys'
        root.mkdir(mode=0o700)
        install, rule = self.applied_cli_fixture([{'type': 'bind', 'source': str(self.workspace / '.env.d/.ssh-server'),
                                                 'target': str(root), 'bind': {'create_host_path': False}}])
        (install / '03-enabled/custom.sh').symlink_to('../available/4010-tool-ssh-server.sh')
        return root, rule

    def assert_unsafe_unselected_blocks_ssh(self, root, rule):
        # This is the installer preflight: failure must precede its root chmod.
        root.chmod(0o777)
        result = self.cli('validate', '--root', rule['root'], '--defer-root', rule['root'])
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.mode(root), 0o777)
        self.assertFalse((root / 'ssh').exists())
        root.chmod(0o700)
        result = self.cli('apply', '--root', rule['root'])
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertFalse((root / 'ssh').exists())

    def test_unselected_applicable_symlink_blocks_scoped_ssh_preflight_and_apply(self):
        root, rule = self.scoped_ssh_fixture()
        self.target.rename(self.target.with_name('original'))
        self.target.symlink_to(self.target.with_name('original'), target_is_directory=True)
        self.assert_unsafe_unselected_blocks_ssh(root, rule)

    def test_unselected_applicable_file_blocks_scoped_ssh_preflight_and_apply(self):
        root, rule = self.scoped_ssh_fixture()
        self.target.rename(self.target.with_name('original'))
        self.target.write_text('not a directory')
        self.assert_unsafe_unselected_blocks_ssh(root, rule)

    def test_unselected_applicable_writable_ancestor_allows_scoped_ssh_preflight_and_apply(self):
        root, rule = self.scoped_ssh_fixture()
        for mode in [0o775, 0o777]:
            with self.subTest(mode=oct(mode)):
                self.target.parent.chmod(mode)
                root.chmod(0o777)
                result = self.cli('validate', '--root', rule['root'], '--defer-root', rule['root'])
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.mode(root), 0o777)
                root.chmod(0o700)
                result = self.cli('apply', '--root', rule['root'])
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.mode(root / 'ssh'), 0o700)
                self.assertEqual(self.mode(self.target), 0o755)
                self.assertEqual(self.mode(self.target.parent), mode)

    def test_unselected_applicable_foreign_owner_blocks_scoped_ssh_apply(self):
        root, rule = self.scoped_ssh_fixture()
        real_fstat = os.fstat
        inode = self.target.stat().st_ino
        def foreign(fd):
            info = real_fstat(fd)
            if info.st_ino == inode:
                fields = list(info)
                fields[4] = os.getuid() + 100
                return os.stat_result(fields)
            return info
        for command, mode, extra in [('validate', 0o777, ['--defer-root', rule['root']]),
                                     ('apply', 0o700, [])]:
            root.chmod(mode)
            with patch.dict(os.environ, DEVCONTAINER_BIND_MANIFEST_ID=self.identity), \
                    patch('sys.argv', [str(HELPER), command, str(self.workspace), '--root', rule['root'], *extra]), \
                    patch.object(permissions.os, 'fstat', side_effect=foreign):
                with self.assertRaisesRegex(ValueError, 'owner'):
                    permissions.main()
            self.assertFalse((root / 'ssh').exists())
            self.assertEqual(self.mode(root), mode)
        self.assertEqual(self.mode(self.target), 0o755)

    def test_unselected_safety_rechecked_after_selected_plan_before_creation(self):
        root, rule = self.scoped_ssh_fixture()
        original = permissions.Plan.__init__
        def change_after_selected(plan, *args, **kwargs):
            original(plan, *args, **kwargs)
            if not plan.validation_only:
                parent = self.target.parent
                parent.rename(parent.with_name('original-review-mode'))
                parent.mkdir()
        with patch.dict(os.environ, DEVCONTAINER_BIND_MANIFEST_ID=self.identity), \
                patch('sys.argv', [str(HELPER), 'apply', str(self.workspace), '--root', rule['root']]), \
                patch.object(permissions.Plan, '__init__', new=change_after_selected):
            with self.assertRaisesRegex(ValueError, 'changed after validation'):
                permissions.main()
        self.assertFalse((root / 'ssh').exists())
        self.assertFalse(self.target.exists())
        self.assertEqual(self.mode(self.target.parent.with_name('original-review-mode') / self.target.name), 0o755)

    def test_full_preflight_never_opens_unselected_leaf_for_read_or_changes_its_mode(self):
        root, rule = self.scoped_ssh_fixture()
        self.target.chmod(0o000)
        self.addCleanup(self.target.chmod, 0o700)
        real_open = os.open
        def deny_read(name, flags, *args, **kwargs):
            if name == 'rar-authority' and not flags & os.O_PATH:
                raise PermissionError('unselected authority must remain metadata-only')
            return real_open(name, flags, *args, **kwargs)
        with patch.dict(os.environ, DEVCONTAINER_BIND_MANIFEST_ID=self.identity), \
                patch('sys.argv', [str(HELPER), 'apply', str(self.workspace), '--root', rule['root']]), \
                patch.object(permissions.os, 'open', side_effect=deny_read):
            permissions.main()
        self.assertEqual(self.mode(self.target), 0o000)
        self.assertEqual(self.mode(root / 'ssh'), 0o700)

    def create_rule(self, path, mode='0700'):
        return dict(self.rule, path=path, mode=mode, missing='create')

    def test_explicit_creation_is_private_then_finalized_bottom_up(self):
        parent = self.workspace / 'new'
        child = parent / 'child'
        rules = self.rules(self.create_rule('new/child', '0000'), self.create_rule('new', '0000'))
        real_chmod = os.fchmod
        observations = []
        def chmod(fd, mode):
            observations.append((self.mode(parent), self.mode(child), mode))
            real_chmod(fd, mode)
        # Retained descriptors allow final 0000 modes without reopening parents.
        with permissions.Plan(self.workspace, rules, []) as plan:
            self.assertFalse(parent.exists())
            with patch.object(permissions.os, 'fchmod', side_effect=chmod):
                plan.apply()
            self.assertEqual(stat.S_IMODE(os.fstat(plan.nodes[('workspace', 'new/child')]['fd']).st_mode), 0)
        self.addCleanup(lambda: (parent.chmod(0o700), child.chmod(0o700)))
        self.assertEqual(observations[0], (0o700, 0o700, 0))
        self.assertEqual(self.mode(parent), 0)

    def test_creation_requires_explicit_missing_intermediates(self):
        for rules in [self.rules(self.create_rule('absent/child')),
                      self.rules(dict(self.rule, path='absent'), self.create_rule('absent/child'))]:
            with self.assertRaises(ValueError):
                self.apply(rules)
            self.assertFalse((self.workspace / 'absent').exists())

    def test_creation_dry_plan_excludes_absent_parents_without_mutation(self):
        for missing in ['skip', 'create']:
            rules = [dict(self.rule, path='absent/child', missing=missing)]
            if missing == 'create':
                rules.append(self.create_rule('absent'))
            with permissions.Plan(self.workspace, self.rules(*rules), []) as plan:
                self.assertIn(str(self.workspace / 'absent'), plan.exclusions)
            self.assertFalse((self.workspace / 'absent').exists())

    def test_creation_validates_entire_plan_before_mkdir(self):
        (self.workspace / 'collision').write_text('file')
        with self.assertRaises((ValueError, OSError)):
            self.apply(self.rules(self.create_rule('new'), self.create_rule('collision')))
        self.assertFalse((self.workspace / 'new').exists())

    def test_creation_collision_after_validation_fails_without_adoption(self):
        path = self.workspace / 'new'
        with permissions.Plan(self.workspace, self.rules(self.create_rule('new')), []) as plan:
            path.mkdir(mode=0o755)
            with self.assertRaises((ValueError, OSError)):
                plan.apply()
        self.assertEqual(self.mode(path), 0o755)

    def test_creation_rechecks_replaced_and_foreign_owned_ancestors(self):
        real_fstat = os.fstat
        for change in ['replace', 'owner']:
            parent = self.workspace / change
            parent.mkdir()
            inode = parent.stat().st_ino
            def foreign(fd):
                info = real_fstat(fd)
                if change == 'owner' and info.st_ino == inode:
                    fields = list(info)
                    fields[4] = os.getuid() + 100
                    return os.stat_result(fields)
                return info
            with permissions.Plan(self.workspace, self.rules(self.create_rule(change + '/child')), []) as plan:
                if change == 'replace':
                    parent.rename(parent.with_name(change + '-original'))
                    parent.mkdir()
                with patch.object(permissions.os, 'fstat', side_effect=foreign), self.assertRaises(ValueError):
                    plan.apply()
            self.assertFalse((parent / 'child').exists())

    def test_create_rejects_symlinks_and_foreign_owner(self):
        (self.workspace / 'link').symlink_to(self.target, target_is_directory=True)
        with self.assertRaises((ValueError, OSError)):
            self.apply(self.rules(self.create_rule('link/child')))
        real_fstat = os.fstat
        def foreign(fd):
            info = real_fstat(fd)
            if info.st_ino == self.target.stat().st_ino:
                fields = list(info)
                fields[4] = os.getuid() + 100
                return os.stat_result(fields)
            return info
        with patch.object(permissions.os, 'fstat', side_effect=foreign):
            with self.assertRaises(ValueError):
                self.apply(self.rules(self.create_rule(self.rule['path'] + '/child')))

    def test_created_directory_replacement_before_chmod_is_rejected(self):
        path = self.workspace / 'new'
        real_mkdir = os.mkdir
        def replace(name, *args, **kwargs):
            real_mkdir(name, *args, **kwargs)
            # Replacement during creation must not be adopted, even if owned.
            path.rename(self.workspace / 'original')
            path.symlink_to(self.target, target_is_directory=True)
        with permissions.Plan(self.workspace, self.rules(self.create_rule('new')), []) as plan:
            with patch.object(permissions.os, 'mkdir', side_effect=replace):
                with self.assertRaises((ValueError, OSError)):
                    plan.apply()
        self.assertEqual(self.mode(self.target), 0o755)

    def test_existing_parent_skip_allows_child_creation_without_parent_mode_change(self):
        parent = self.workspace / 'existing'
        parent.mkdir(mode=0o710)
        rules = self.rules(dict(self.rule, path='existing', mode='0710'),
                           self.create_rule('existing/child', '0750'))
        for _ in range(2):
            self.apply(rules)
        self.assertEqual(self.mode(parent), 0o710)
        self.assertEqual(self.mode(parent / 'child'), 0o750)

    def test_created_modes_are_private_under_permissive_umask_and_umask_restored(self):
        real_mkdir = os.mkdir
        modes = []
        def observe(name, *args, **kwargs):
            real_mkdir(name, *args, **kwargs)
            modes.append(stat.S_IMODE(os.stat(name, dir_fd=kwargs['dir_fd']).st_mode))
        old_umask = os.umask(0)
        try:
            with patch.object(permissions.os, 'mkdir', side_effect=observe):
                self.apply(self.rules(self.create_rule('public-final', '0777')))
            restored = os.umask(0)
            self.assertEqual(restored, 0)
        finally:
            os.umask(old_umask)
        self.assertEqual(modes, [0o700])
        self.assertEqual(self.mode(self.workspace / 'public-final'), 0o777)

    def test_creation_failure_is_nontransactional_but_unfinalized_nodes_stay_private(self):
        real_mkdir = os.mkdir
        def fail_second(name, *args, **kwargs):
            if name == 'second':
                raise PermissionError(errno.EACCES, 'fixture failure')
            return real_mkdir(name, *args, **kwargs)
        with patch.object(permissions.os, 'mkdir', side_effect=fail_second):
            with self.assertRaises(PermissionError):
                self.apply(self.rules(self.create_rule('first', '0755'), self.create_rule('second')))
        self.assertEqual(self.mode(self.workspace / 'first'), 0o700)
        self.assertFalse((self.workspace / 'second').exists())

    def test_new_directory_owner_is_checked_before_final_mode(self):
        path = self.workspace / 'new'
        real_fstat = os.fstat
        def foreign(fd):
            info = real_fstat(fd)
            if path.exists() and info.st_ino == path.stat().st_ino:
                fields = list(info)
                fields[4] = os.getuid() + 100
                return os.stat_result(fields)
            return info
        with permissions.Plan(self.workspace, self.rules(self.create_rule('new', '0755')), []) as plan:
            with patch.object(permissions.os, 'fstat', side_effect=foreign):
                with self.assertRaises(ValueError):
                    plan.apply()
        self.assertEqual(self.mode(path), 0o700)

    def test_inode_replacement_between_creation_stat_and_open_is_rejected(self):
        path = self.workspace / 'new'
        real_open = os.open
        def replace(name, *args, **kwargs):
            if name == 'new':
                path.rename(self.workspace / 'original')
                path.mkdir(mode=0o700)
            return real_open(name, *args, **kwargs)
        with permissions.Plan(self.workspace, self.rules(self.create_rule('new', '0755')), []) as plan:
            with patch.object(permissions.os, 'open', side_effect=replace):
                with self.assertRaisesRegex(ValueError, 'changed during creation'):
                    plan.apply()
        self.assertEqual(self.mode(path), 0o700)
        self.assertEqual(self.mode(self.workspace / 'original'), 0o700)

    def test_multiple_zero_mode_trees_finalize_without_retraversing_closed_parents(self):
        rules = self.rules(*(self.create_rule(path, '0000')
                             for path in ['first', 'first/child', 'second', 'second/child']))
        with permissions.Plan(self.workspace, rules, []) as plan:
            plan.apply()
            for node in plan.nodes.values():
                self.assertEqual(stat.S_IMODE(os.fstat(node['fd']).st_mode), 0)
        for name in ['first', 'second']:
            (self.workspace / name).chmod(0o700)
            (self.workspace / name / 'child').chmod(0o700)

    def test_cli_dry_runs_create_rules_without_filesystem_mutation(self):
        scripts = self.workspace / '.taskfiles/scripts'
        scripts.mkdir(parents=True)
        (scripts / 'compose-manifest.py').write_text(
            'def load_manifest(workspace, runtime=False):\n'
            '    assert runtime\n'
            '    return {"volumes": []}\n')
        config = self.workspace / '.devcontainer/config'
        config.mkdir(parents=True)
        (config / 'runtime-directory-permissions.json').write_text(json.dumps({
            'version': 1, 'rules': [self.create_rule('absent'), self.create_rule('absent/child')]}))
        for command in ['validate', 'exclusions']:
            result = subprocess.run(['python3', str(HELPER), command, str(self.workspace)],
                                    capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((self.workspace / 'absent').exists())
        self.assertIn(os.fsencode(self.workspace / 'absent') + b'\0', result.stdout)

    def test_entire_plan_validated_before_first_chmod(self):
        collision = self.workspace / 'collision'
        collision.write_text('file')
        with self.assertRaises((ValueError, OSError)):
            self.apply(self.rules(self.rule, dict(self.rule, path='collision')))
        self.assertEqual(self.mode(self.target), 0o755)

    def test_symlink_components_rejected_and_writable_ancestors_accepted(self):
        (self.workspace / 'link').symlink_to(self.target, target_is_directory=True)
        for path in ['link', 'link/absent']:
            with self.subTest(path=path), self.assertRaises(NotADirectoryError):
                self.apply(self.rules(dict(self.rule, path=path)))
        self.assertEqual(self.mode(self.target), 0o755)
        for mode in [0o775, 0o777]:
            with self.subTest(mode=oct(mode)):
                self.target.parent.chmod(mode)
                self.apply()
                self.assertEqual(self.mode(self.target.parent), mode)
                self.assertEqual(self.mode(self.target), 0o700)

    def test_unexpected_owner_and_non_enoent_never_skip(self):
        real_fstat = os.fstat
        def foreign(fd):
            result = real_fstat(fd)
            if result.st_ino == self.target.stat().st_ino:
                fields = list(result)
                fields[4] = os.getuid() + 100
                return os.stat_result(fields)
            return result
        with patch.object(permissions.os, 'fstat', side_effect=foreign):
            with self.assertRaises(ValueError):
                self.apply()
        real_open = os.open
        def denied(path, *args, **kwargs):
            if path == 'rar-authority':
                raise PermissionError(errno.EACCES, 'denied')
            return real_open(path, *args, **kwargs)
        with patch.object(permissions.os, 'open', side_effect=denied):
            with self.assertRaises(PermissionError):
                self.apply()

    def test_managed_root_metadata_modes_and_exclusions(self):
        root = Path(self.temp.name) / 'managed'
        root.mkdir(mode=0o711)
        (root / 'private').mkdir()
        record = {'type': 'bind', 'source': '.env.d/.gentle-ai', 'target': str(root),
                  'managed': True, 'read_only': False}
        rule = dict(self.rule, root=record['source'], path='private')
        before = root.stat()
        with permissions.Plan(self.workspace, self.rules(rule), [record]) as plan:
            self.assertIn(str(self.workspace / record['source']), plan.exclusions)
            plan.apply()
        self.assertEqual(root.stat(), before)
        self.assertEqual(self.mode(root / 'private'), 0o700)
        for change in [{'managed': False}, {'read_only': True}, {'type': 'volume'}]:
            with self.assertRaises(ValueError):
                self.apply(self.rules(rule), [dict(record, **change)])
        file_root = Path(self.temp.name) / 'file'
        file_root.write_text('not a directory')
        with self.assertRaises((ValueError, OSError)):
            self.apply(self.rules(rule), [dict(record, target=str(file_root))])
        with self.assertRaises(ValueError):
            self.apply(self.rules(rule), [record, dict(record, target=str(root / 'private'))])

    def test_workspace_cannot_bypass_mount_restrictions(self):
        mount = self.workspace / 'mount'
        mount.mkdir()
        (mount / 'private').mkdir()
        record = {'type': 'bind', 'source': 'external', 'target': str(mount),
                  'managed': False, 'read_only': True}
        with self.assertRaises(ValueError):
            self.apply(self.rules(dict(self.rule, path='mount/private')), [record])

    def test_nested_source_alias_rules_are_ambiguous_even_with_distinct_targets(self):
        volumes = []
        rules = []
        for source, target, path in [('.env.d/state', 'first', 'nested/private'),
                                     ('.env.d/state/nested', 'second', 'private')]:
            root = Path(self.temp.name) / target
            (root / path).mkdir(parents=True)
            volumes.append({'type': 'bind', 'source': source, 'target': str(root),
                            'managed': True, 'read_only': False})
            rules.append(dict(self.rule, root=source, path=path))
        with self.assertRaises(ValueError):
            self.apply(self.rules(*rules), volumes)

    def test_git_file_is_explicitly_unsupported(self):
        workspace = Path(self.temp.name) / 'worktree'
        workspace.mkdir()
        (workspace / '.git').write_text('gitdir: /do/not/read')
        with self.assertRaisesRegex(ValueError, 'unsupported'):
            with permissions.Plan(workspace, self.rules(), []):
                pass

    def test_replacement_after_validation_is_refused(self):
        with permissions.Plan(self.workspace, self.rules(), []) as plan:
            self.target.rename(self.target.with_name('original'))
            self.target.mkdir()
            with self.assertRaises(ValueError):
                plan.apply()
        self.assertEqual(self.mode(self.target), 0o755)
        self.assertEqual(self.mode(self.target.with_name('original')), 0o755)

    def test_cli_applied_manifest_gate_and_duplicate_json_keys(self):
        scripts = self.workspace / '.taskfiles/scripts'
        scripts.mkdir(parents=True)
        (scripts / 'compose-manifest.py').write_text(
            'def load_manifest(workspace, runtime=False):\n'
            '    assert runtime\n'
            '    raise SystemExit("not applied")\n')
        config = self.workspace / '.devcontainer/config'
        config.mkdir(parents=True)
        policy = config / 'runtime-directory-permissions.json'
        policy.write_text(json.dumps({'version': 1, 'rules': [self.rule]}))
        result = subprocess.run(['python3', str(HELPER), 'apply', str(self.workspace)],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('not applied', result.stderr)
        self.assertEqual(self.mode(self.target), 0o755)
        with self.assertRaises(ValueError):
            permissions.unique_object([('mode', '0700'), ('mode', '0755')])

    def test_cli_real_applied_manifest_selects_full_managed_metadata(self):
        scripts = self.workspace / '.taskfiles/scripts'
        scripts.mkdir(parents=True)
        shutil.copyfile(REPO / '.taskfiles/scripts/compose-manifest.py', scripts / 'compose-manifest.py')
        manifest_spec = importlib.util.spec_from_file_location('manifest_fixture', scripts / 'compose-manifest.py')
        assert manifest_spec is not None and manifest_spec.loader is not None
        manifest_module = importlib.util.module_from_spec(manifest_spec)
        manifest_spec.loader.exec_module(manifest_module)
        root = Path(self.temp.name) / 'managed'
        root.mkdir(mode=0o711)
        (root / 'private').mkdir()
        config = self.workspace / '.devcontainer/config'
        config.mkdir(parents=True)
        rule = dict(self.rule, root='.env.d/.gentle-ai', path='private')
        (config / 'runtime-directory-permissions.json').write_text(json.dumps({'version': 1, 'rules': [rule]}))
        manifest = manifest_module.project_manifest(
            self.workspace, 'container-svc', [self.workspace / '.devcontainer/docker-compose.yml'],
            {'volumes': [{'type': 'bind', 'source': str(self.workspace / rule['root']),
                          'target': str(root), 'bind': {'create_host_path': False}}]})
        snapshot = self.workspace / manifest_module.MANIFEST
        snapshot.write_text(json.dumps(manifest))
        before = root.stat()
        for identity, expected in [(manifest['id'], 0), ('unapplied', 1)]:
            result = subprocess.run(['python3', str(HELPER), 'apply', str(self.workspace)],
                                    env=dict(os.environ, DEVCONTAINER_BIND_MANIFEST_ID=identity),
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, expected, result.stderr)
        self.assertEqual(self.mode(root / 'private'), 0o700)
        self.assertEqual(root.stat(), before)

    def test_setup_normalizer_and_tracked_restore_protect_policy_subtrees(self):
        scripts = self.workspace / '.taskfiles/scripts'
        scripts.mkdir(parents=True)
        config = self.workspace / '.devcontainer/config'
        config.mkdir(parents=True)
        lifecycle = self.workspace / '.devcontainer/lifecycle'
        lifecycle.mkdir(parents=True)
        for name in ['runtime-directory-permissions.py', 'restore-tracked-modes.sh']:
            shutil.copyfile(REPO / '.devcontainer/lifecycle' / name, lifecycle / name)
        (config / 'runtime-directory-permissions.json').write_text(json.dumps(
            {'version': 1, 'rules': [self.rule, dict(self.rule, path='absent[tree]'),
                                     self.conditional_fixture()[1]]}))
        bind_source = self.workspace / '.env.d/.gentle-ai'
        bind_source.mkdir(parents=True, mode=0o711)
        source_sentinel = bind_source / 'tracked.sh'
        source_sentinel.write_text('host-owned state')
        source_sentinel.chmod(0o600)
        source_before = bind_source.stat()
        mounted = Path(self.temp.name) / 'mounted'
        mounted.mkdir()
        (scripts / 'compose-manifest.py').write_text(
            'def load_manifest(workspace, runtime=False):\n'
            '    assert runtime\n'
            '    return ' + repr({'volumes': [{'type': 'bind', 'source': '.env.d/.gentle-ai',
                                            'target': str(mounted), 'managed': True,
                                            'read_only': False}]}) + '\n')
        sentinel = self.target / 'tracked.sh'
        sentinel.write_text('preserved')
        sentinel.chmod(0o600)
        ordinary = self.workspace / 'ordinary.sh'
        ordinary.write_text('ordinary')
        ordinary.chmod(0o600)
        source = (REPO / '.devcontainer/setup.sh').read_text()
        body = source[source.index('build_gitignore_prune_args()'):source.index('# Copy the file tree')]
        # General application follows specialized SSH recovery in production;
        # this fixture has SSH disabled, so execute the actual application line.
        body += next(line + '\n' for line in source.splitlines()
                     if line.startswith('python3 ') and ' apply ' in line)
        preamble = '''set -euo pipefail
WORKSPACE_DIR="$1"
SCRIPT_DIR="$1/.devcontainer"
runtime_root_expectations=()
git() {
  if [[ "$*" == *--stage* ]]; then
    printf '100755 hash 0\\t.git/gentle-ai/review-mode/rar-authority/tracked.sh\\0'
    printf '100644 hash 0\\tordinary.sh\\0'
    printf '100755 hash 0\\t.env.d/.gentle-ai/tracked.sh\\0'
    printf '100755 hash 0\\tabsent[tree]/tracked.sh\\0'
  elif [[ "$*" == *--git-dir* || "$*" == *--git-common-dir* ]]; then
    printf '%s\n' "$WORKSPACE_DIR/.git"
  else
    mkdir -p "$WORKSPACE_DIR/absent[tree]"
    printf preserved > "$WORKSPACE_DIR/absent[tree]/tracked.sh"
    chmod 600 "$WORKSPACE_DIR/absent[tree]/tracked.sh"
  fi
}
sudo() { command "$@"; }
chown() { :; }
export -f git sudo chown
'''
        result = subprocess.run(['bash', '-c', preamble + body, '_', str(self.workspace)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.mode(self.target), 0o700)
        self.assertEqual(self.mode(sentinel), 0o600)
        self.assertEqual(self.mode(ordinary), 0o644)
        self.assertEqual(bind_source.stat(), source_before)
        self.assertEqual(self.mode(source_sentinel), 0o600)
        self.assertEqual(self.mode(self.workspace / 'absent[tree]'), 0o700)
        self.assertEqual(self.mode(self.workspace / 'absent[tree]/tracked.sh'), 0o600)
        # Invalid preflight must stop before generic normalizers and index restoration.
        self.target.rename(self.target.with_name('original-authority'))
        self.target.symlink_to(self.target.with_name('original-authority'), target_is_directory=True)
        ordinary.chmod(0o600)
        result = subprocess.run(['bash', '-c', preamble + body, '_', str(self.workspace)],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('preflight failed', result.stderr)
        self.assertEqual(self.mode(ordinary), 0o600)



class NormalizationTests(unittest.TestCase):
    """Run only generic normalization in owned fixtures, with no privilege escalation."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'workspace'
        self.root.mkdir()
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        scripts = self.root / '.devcontainer/lifecycle'
        scripts.mkdir(parents=True)
        shutil.copyfile(REPO / '.devcontainer/lifecycle/restore-tracked-modes.sh',
                        scripts / 'restore-tracked-modes.sh')
        (self.root / '.gitignore').write_text('.env\nignored.sh\nliteral*\nignored/\nlink\ntracked-ignored.sh\n')
        for name in ('.env', 'ignored.sh', 'literal[*?]\\name\n.sh', 'ignored/private.sh'):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'synthetic unchanged bytes')
            path.chmod(0o600)
        (self.root / 'ignored').chmod(0o711)
        self.external = Path(self.temp.name) / 'external'
        self.external.mkdir(mode=0o700)
        (self.external / 'payload').write_bytes(b'synthetic target')
        (self.root / 'link').symlink_to(self.external, target_is_directory=True)
        for name in ('ordinary.sh', 'executable.txt', 'tracked-ignored.sh'):
            (self.root / name).write_bytes(b'public')
            (self.root / name).chmod(0o600)
        self.source = (REPO / '.devcontainer/setup.sh').read_text()
        self.bin = Path(self.temp.name) / 'bin'
        self.bin.mkdir()
        chown = self.bin / 'chown'
        chown.write_text('#!/bin/bash\n'
                         '# Simulate a foreign-owned ignored entry that cannot be repaired.\n'
                         'for path in "$@"; do\n'
                         '  [[ "$path" != "$WORKSPACE_DIR/.env" ]] || exit 17\n'
                         'done\n'
                         'printf "%s\\0" "$@" >> "$WORKSPACE_DIR/chown-calls"\n')
        chown.chmod(0o755)

    def run_normalization(self, failure='', gitfile=False, git_dirs=None):
        function = self.source[self.source.index('build_gitignore_prune_args()'):
                               self.source.index('# Preflight and collect protected subtrees')]
        passes = self.source[self.source.index('gitignore_prune_args=()'):
                             self.source.index('# Copy the file tree')]
        preamble = '''set -euo pipefail
WORKSPACE_DIR="$1"
SCRIPT_DIR="$1/.devcontainer"
runtime_exclusions=("$WORKSPACE_DIR/missing-policy-root")
sudo() { command "$@"; }
git() {
  case "$*" in
    *--stage*) printf '100644 hash 0\\tordinary.sh\\0';
               printf '100755 hash 0\\texecutable.txt\\0';
               printf '100644 hash 0\\ttracked-ignored.sh\\0' ;;
    *--git-common-dir*)
      if [[ "$FAILURE" == resolution ]]; then return 17; fi
      printf '%s\\n' "$COMMON" ;;
    *--git-dir*)
      if [[ "$FAILURE" == resolution ]]; then return 17; fi
      printf '%s\\n' "$METADATA" ;;
    *--ignored*)
      if [[ "$FAILURE" == enumeration ]]; then return 17; fi
      if [[ "$GITFILE" == yes ]]; then printf '.env\\0'; return 0; fi
      # Synthetic index supplies tracked-ignored.sh without staging any file.
      command git "$@" -- ':!:tracked-ignored.sh' ;;
    *) return 99 ;;
  esac
}
export -f sudo git
export WORKSPACE_DIR
'''
        metadata = self.external if gitfile else self.root / '.git'
        metadata, common = git_dirs or (metadata, metadata)
        preamble += 'FAILURE=' + shlex.quote(failure) + '\n'
        preamble += 'METADATA=' + shlex.quote(str(metadata)) + '\n'
        preamble += 'COMMON=' + shlex.quote(str(common)) + '\n'
        preamble += 'GITFILE=' + ('yes' if gitfile else 'no') + '\n'
        preamble += 'export PATH=' + shlex.quote(str(self.bin)) + ':"$PATH"\n'
        return subprocess.run(['bash', '-c', preamble + function + passes, '_', str(self.root)],
                              capture_output=True, text=True)

    def test_ignored_literals_and_git_metadata_preserve_modes_bytes_and_owners(self):
        protected = [self.root / name for name in
                     ('.env', 'ignored.sh', 'literal[*?]\\name\n.sh', 'ignored',
                      'ignored/private.sh', 'link', '.git', '.git/config')]
        before = {path: (path.lstat(), None if path.is_dir() or path.is_symlink() else path.read_bytes())
                  for path in protected}
        result = self.run_normalization()
        self.assertEqual(result.returncode, 0, result.stderr)
        for path, (metadata, contents) in before.items():
            after = path.lstat()
            self.assertEqual((after.st_mode, after.st_uid, after.st_gid),
                             (metadata.st_mode, metadata.st_uid, metadata.st_gid))
            if contents is not None:
                self.assertEqual(path.read_bytes(), contents)
        calls = (self.root / 'chown-calls').read_bytes().split(b'\0')
        self.assertTrue(all(os.fsencode(path) not in calls for path in protected))
        for name, mode in (('ordinary.sh', 0o644), ('executable.txt', 0o755), ('tracked-ignored.sh', 0o644)):
            self.assertEqual(stat.S_IMODE((self.root / name).stat().st_mode), mode)

    def test_git_failures_block_every_normalization_pass(self):
        for failure in ('resolution', 'enumeration'):
            with self.subTest(failure=failure):
                result = self.run_normalization(failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((self.root / 'chown-calls').exists())
                self.assertEqual(stat.S_IMODE((self.root / 'ordinary.sh').stat().st_mode), 0o600)

    def test_gitfile_and_external_metadata_are_not_normalized(self):
        shutil.rmtree(self.root / '.git')
        (self.root / '.git').write_text('gitdir: ' + str(self.external) + '\n')
        (self.root / '.git').chmod(0o600)
        before = self.external.stat(), (self.external / 'payload').stat()
        # Mock enumeration: the external tree is not a Git repository.
        result = self.run_normalization(gitfile=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(stat.S_IMODE((self.root / '.git').stat().st_mode), 0o600)
        self.assertEqual((self.external.stat(), (self.external / 'payload').stat()), before)

    def test_contained_git_directory_and_common_directory_are_both_pruned(self):
        directories = [self.root / name for name in ('admin/worktree', 'admin/common')]
        for directory in directories:
            directory.mkdir(parents=True, mode=0o700)
            (directory / 'private.sh').write_bytes(b'synthetic metadata')
            (directory / 'private.sh').chmod(0o600)
        result = self.run_normalization(git_dirs=directories)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = (self.root / 'chown-calls').read_bytes().split(b'\0')
        for directory in directories:
            self.assertEqual(stat.S_IMODE(directory.stat().st_mode), 0o700)
            self.assertEqual(stat.S_IMODE((directory / 'private.sh').stat().st_mode), 0o600)
            self.assertNotIn(os.fsencode(directory), calls)
            self.assertNotIn(os.fsencode(directory / 'private.sh'), calls)


if __name__ == '__main__':
    unittest.main()
