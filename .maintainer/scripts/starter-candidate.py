#!/usr/bin/env python3
"""Build or cancel a local, filtered starter release candidate."""

import argparse
import importlib.util
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys


# Status must remain read-only even without caller-supplied Python settings.
sys.dont_write_bytecode = True
script = Path(__file__).with_name("starter-source.py")
spec = importlib.util.spec_from_file_location("starter_source", script)
assert spec is not None and spec.loader is not None
source_tree = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source_tree)
git = source_tree.git
require = source_tree.require
branch = source_tree.branch
exists = source_tree.exists

SOURCE = "Starter-Candidate-Source: "
BASE = "Starter-Candidate-Base: "
SUBJECT = "Prepare starter release candidate"
RELEASE_SUBJECT = "Publish consumer starter"
RELEASE_SOURCE = "Starter-Release-Source: "
ZERO = "0" * 40


def checked_out(ref):
    return any(line == f"branch {ref}" for line in git("worktree", "list", "--porcelain").splitlines())


def identity(commit):
    message = git("show", "-s", "--format=%B", commit)
    source, base, policy, normalization = source_tree.identity_metadata(message, SUBJECT, (SOURCE, BASE))
    parents = git("show", "-s", "--format=%P", commit).split()
    require(len(parents) <= 1, "candidate must have at most one candidate parent")
    require(git("cat-file", "-t", source) == "commit", "invalid candidate source")
    require(base == ZERO or git("cat-file", "-t", base) == "commit", "invalid candidate base")
    require(git("rev-parse", f"{commit}^{{tree}}") == source_tree.filtered_tree(source, policy, normalization),
            "candidate tree does not match committed source")
    return source, base, parents, policy, normalization


def published_candidate(release, prior, source, pinned_base, policy, normalization):
    message = git("show", "-s", "--format=%B", release)
    release_source, release_policy, release_normalization = source_tree.identity_metadata(
        message, RELEASE_SUBJECT, (RELEASE_SOURCE,))
    require((release_source, release_policy, release_normalization) == (source, policy, normalization),
            "release is not a publication of the candidate")
    parents = git("show", "-s", "--format=%P", release).split()
    require(parents == ([] if pinned_base == ZERO else [pinned_base]),
            "release does not descend directly from candidate base")
    require(git("rev-parse", f"{release}^{{tree}}") == git("rev-parse", f"{prior}^{{tree}}"),
            "release tree differs from candidate")


def metadata(commit):
    """Inspect identity and ancestry without recomputing or writing filtered trees."""
    require(git("cat-file", "-t", commit) == "commit", "candidate must be a commit")
    source, base, policy, normalization = source_tree.identity_metadata(
        git("show", "-s", "--format=%B", commit), SUBJECT, (SOURCE, BASE))
    parents = git("show", "-s", "--format=%P", commit).split()
    require(len(parents) <= 1, "candidate must have at most one candidate parent")
    require(source != ZERO, "invalid candidate source")
    for value in (source, base):
        if value != ZERO:
            require(git("rev-parse", "--verify", f"{value}^{{commit}}") == value,
                    "candidate identity requires a full commit ID")
    return source, base, parents, policy, normalization


def report(args, rc, source, pinned_base, policy, normalization, *, promoted=False):
    tree = git("rev-parse", f"{rc}^{{tree}}")
    base = "absent" if pinned_base == ZERO else pinned_base
    print("Local identity report (metadata only for status; not approval or full tree validation).")
    print("Already published locally." if promoted else "unapproved local candidate")
    for label, value in (("RC", rc), ("Source", source), ("Tree", tree),
                         ("Pinned base", base), ("Compose policy", policy or "legacy"),
                         ("Tools normalization", normalization or "legacy")):
        print(f"{label}: {value}")
    task = ["task", "--taskfile", ".maintainer/Taskfile.yml"]
    if not promoted:
        command = task + ["distribution:promote", "--", "--candidate", args.target,
                          "--target", args.base, "--approved-rc", rc, "--expected-tree", tree,
                          "--expected-base", base, "--expected-source", source]
        print("Promote only after explicit review/approval: " + shlex.join(command))
    command = task + ["distribution:reject", "--", "--source", args.source,
                      "--target", args.target, "--base", args.base, "--expected-rc", rc]
    if pinned_base == ZERO and not promoted:
        command.append("--base-absent")
    print("Guarded RC deletion (not release rollback): " + shlex.join(command))


def blocked_diagnostics(args, target_ref, base_ref, error):
    """Best-effort, read-only identities; never replace the guard's original error."""
    def inspect(*command):
        try:
            return git(*command)
        except (ValueError, subprocess.CalledProcessError, OSError, UnicodeError):
            return "unavailable"

    rc = inspect("rev-parse", "--verify", target_ref)
    reasons = {
        "invalid starter identity metadata": "recorded identity metadata is malformed or unavailable.",
        "invalid candidate source": "recorded candidate source is invalid.",
        "invalid candidate base": "recorded candidate base is invalid.",
        "candidate identity requires a full commit ID": "recorded source or base cannot be verified as a full commit ID.",
        "candidate parent has unexpected provenance": "candidate ancestry does not match its recorded provenance.",
        "candidate tree does not match committed source": "candidate tree differs from its recorded source.",
        "release base changed; refuse stale candidate": "the release base no longer matches this RC.",
        "release base presence does not match --base-absent": "release presence conflicts with the requested base mode.",
        "release is not a publication of the candidate": "the current release is not a publication of this RC.",
        "release does not descend directly from candidate base": "the current release has unexpected ancestry.",
        "release tree differs from candidate": "the current release tree differs from this RC.",
        "status requires nonsymbolic local refs": "a local ref is symbolic rather than an independent branch.",
        "local branch must point to a commit": "a local branch does not identify a commit.",
    }
    reason = reasons.get(str(error), "candidate state could not be verified; see the original error.")
    base_errors = {"release base changed; refuse stale candidate",
                   "release base presence does not match --base-absent",
                   "release is not a publication of the candidate", "invalid starter identity metadata"}
    if str(error) in base_errors:
        try:
            # Metadata validity supports an explanation, not approval or tree validation.
            _, pinned_base, _, _, _ = metadata(rc)
            current = git("rev-parse", "--verify", base_ref) if exists(base_ref) else ZERO
            if pinned_base == ZERO and current != ZERO:
                reason = f"this RC expected no {args.base} release, but {args.base} now exists."
            elif pinned_base != ZERO and current == ZERO:
                reason = f"this RC's expected {args.base} release is missing."
        except (ValueError, subprocess.CalledProcessError, OSError, UnicodeError):
            pass
    if not args.verbose:
        print(f"Blocked RC: {rc}")
        print(f"Reason: {reason}")
        return

    tree = inspect("rev-parse", "--verify", f"{rc}^{{tree}}") if rc != "unavailable" else rc
    message = inspect("show", "-s", "--format=%B", rc) if rc != "unavailable" else ""

    def claimed_commit(header, *, absent=False):
        values = [line[len(header):] for line in message.splitlines() if line.startswith(header)]
        if len(values) != 1 or re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", values[0]) is None:
            return "unavailable"
        value = values[0]
        if value == ZERO:
            return "absent" if absent else "unavailable"
        return value if inspect("rev-parse", "--verify", f"{value}^{{commit}}") == value else "unavailable"

    # show-ref distinguishes absence from a failed inspection; no status/index refresh.
    try:
        presence = subprocess.run(["git", "show-ref", "--verify", "--quiet", base_ref]).returncode
    except OSError:
        presence = -1
    base = "absent" if presence == 1 else inspect("rev-parse", "--verify", base_ref)
    print(f"Reason: {reason}")
    print("Diagnostic only (metadata claims; not approval or full filtered-tree validation).")
    for label, value in (("Candidate branch", args.target), ("RC", rc),
                         ("Source", claimed_commit(SOURCE)), ("Tree", tree),
                         ("Pinned base", claimed_commit(BASE, absent=True)), ("Current base", base)):
        print(f"{label}: {value}")


def status_report(args, target_ref, base_ref):
    # This path deliberately does not call identity()/filtered_tree(), status,
    # temporary-index helpers, or any object/ref writer. Dirty worktrees are OK.
    if not exists(target_ref):
        print("State: absent (no local candidate)")
        return
    rc = git("rev-parse", target_ref)
    source, pinned_base, parents, policy, normalization = metadata(rc)
    descendant_source = source
    while parents:
        parent_source, parent_base, parents, _, _ = metadata(parents[0])
        require(parent_base == pinned_base and
                subprocess.run(["git", "merge-base", "--is-ancestor", parent_source, descendant_source],
                               capture_output=True).returncode == 0,
                "candidate parent has unexpected provenance")
        descendant_source = parent_source
    base = git("rev-parse", base_ref) if exists(base_ref) else ZERO
    promoted = base != pinned_base
    if promoted:
        require(base != ZERO, "release base changed; refuse stale candidate")
        published_candidate(base, rc, source, pinned_base, policy, normalization)
    print("State: directly-promoted" if promoted else "State: pending")
    report(args, rc, source, pinned_base, policy, normalization, promoted=promoted)


def expected_rc(value):
    # Match the repository's full object-ID width, not an abbreviation/range.
    width = 64 if git("rev-parse", "--show-object-format") == "sha256" else 40
    require(re.fullmatch(r"[0-9a-f]{" + str(width) + r"}", value) is not None,
            "expected full hexadecimal RC object ID")
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default="dev", help="committed local source branch")
    parser.add_argument("--target", default="starter-rc", help="local candidate branch")
    parser.add_argument("--base", default="starter", help="local release branch")
    parser.add_argument("--base-absent", action="store_true", help="pin an absent release branch for an initial root release")
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--cancel", action="store_true", help="legacy deletion of a verified candidate")
    modes.add_argument("--reject", action="store_true", help="delete only the explicitly pinned verified candidate")
    modes.add_argument("--status", action="store_true", help="read-only local identity inspection, not full tree validation")
    parser.add_argument("--expected-rc", help="full candidate commit ID required by --reject")
    parser.add_argument("--verbose", action="store_true", help="include metadata details in blocked candidate/status diagnostics")
    args = parser.parse_args()
    require(args.reject == (args.expected_rc is not None), "--reject requires --expected-rc; pin is exclusive to rejection")
    require(not (args.status and args.base_absent), "status discovers base presence; omit --base-absent")
    pin = expected_rc(args.expected_rc) if args.reject else None
    deleting = args.cancel or args.reject
    source_ref, target_ref, base_ref = map(branch, (args.source, args.target, args.base))
    require(len({source_ref, target_ref, base_ref}) == 3, "source, candidate and base must differ")
    require(git("rev-parse", "--show-toplevel") == os.getcwd(), "run from the repository root")
    if args.status:
        try:
            for ref in (source_ref, target_ref, base_ref):
                require(subprocess.run(["git", "symbolic-ref", "-q", ref],
                                       capture_output=True).returncode == 1,
                        "status requires nonsymbolic local refs")
                if exists(ref):
                    require(git("cat-file", "-t", git("rev-parse", ref)) == "commit",
                            "local branch must point to a commit")
            status_report(args, target_ref, base_ref)
        except (ValueError, subprocess.CalledProcessError) as error:
            print("State: inconsistent")
            blocked_diagnostics(args, target_ref, base_ref, error)
            raise
        return
    require(not git("status", "--porcelain", "--untracked-files=all"),
            "worktree and index must be clean")
    require(subprocess.run(["git", "symbolic-ref", "-q", target_ref],
                           capture_output=True).returncode == 1,
            "candidate target must not be a symbolic ref")
    require(not checked_out(target_ref),
            "candidate branch must not be checked out")
    try:
        require(exists(base_ref) != args.base_absent,
                "release base presence does not match --base-absent")
    except ValueError as error:
        if not deleting and exists(target_ref):
            blocked_diagnostics(args, target_ref, base_ref, error)
        raise
    base = ZERO if args.base_absent else git("rev-parse", base_ref)
    require(exists(source_ref) or deleting, "source must be an existing local branch")
    source = git("rev-parse", source_ref) if exists(source_ref) else None
    prior = git("rev-parse", target_ref) if exists(target_ref) else None
    if args.reject:
        require(prior == pin, "candidate moved since rejection pin or is missing")
    if prior:
        try:
            old_source, old_base, parents, old_policy, old_normalization = identity(prior)
            if old_base != base:
                require(deleting and base != ZERO,
                        "release base changed; refuse stale candidate")
                published_candidate(base, prior, old_source, old_base, old_policy, old_normalization)
            descendant_source = old_source
            while parents:
                parent_source, parent_base, parents, _, _ = identity(parents[0])
                require(parent_base == old_base and
                        subprocess.run(["git", "merge-base", "--is-ancestor", parent_source, descendant_source]).returncode == 0,
                        "candidate parent has unexpected provenance")
                descendant_source = parent_source
        except (ValueError, subprocess.CalledProcessError) as error:
            if not deleting:
                blocked_diagnostics(args, target_ref, base_ref, error)
            raise
        if deleting:
            git("update-ref", "-d", target_ref, pin if args.reject else prior)
            print(f"Canceled {args.target} at {prior}; release unchanged.")
            return
        require(source is not None, "source must be an existing local branch")
        assert source is not None
        require(subprocess.run(["git", "merge-base", "--is-ancestor", old_source, source]).returncode == 0,
                "source must advance candidate source; cancel before replacing")
        if (source == old_source and old_policy == source_tree.CURRENT_COMPOSE_POLICY
                and old_normalization == source_tree.CURRENT_TOOLS_NORMALIZATION):
            print("Candidate already contains this source; nothing to update.")
            report(args, prior, old_source, old_base, old_policy, old_normalization)
            return
    else:
        require(not deleting, "no candidate to cancel")
    require(source is not None, "source must be an existing local branch")

    try:
        tree = source_tree.filtered_tree(source)
    except ValueError as error:
        raise ValueError(f"new candidate requires valid committed publication inputs: {error}") from error
    message = (f"{SUBJECT}\n\n{SOURCE}{source}\n{BASE}{base}\n"
               f"{source_tree.COMPOSE_POLICY_HEADER}{source_tree.CURRENT_COMPOSE_POLICY}\n"
               f"{source_tree.TOOLS_NORMALIZATION_HEADER}{source_tree.CURRENT_TOOLS_NORMALIZATION}\n")
    commit = git("commit-tree", tree, *(["-p", prior] if prior else []), input=message.encode())
    git("update-ref", target_ref, commit, prior or ZERO)
    print(f"Candidate {args.target} at {commit}; source {source}; base {base}.")
    report(args, commit, source, base, source_tree.CURRENT_COMPOSE_POLICY,
           source_tree.CURRENT_TOOLS_NORMALIZATION)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"starter candidate: {error}", file=sys.stderr)
        sys.exit(1)
