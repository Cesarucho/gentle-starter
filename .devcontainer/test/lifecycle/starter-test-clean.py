#!/usr/bin/env python3
"""Explicit recovery of registered test runs; default invocation is read-only."""

import argparse
from pathlib import Path
import sys
import uuid

from test_resources import Run, Unsafe, command, private, registry_path


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", help="select one run UUID from the preview")
    parser.add_argument("--apply", action="store_true", help="delete only the selected run's verified resources")
    parser.add_argument("--forget", action="store_true", help="also remove the resource-free run's retained diagnostic record")
    args = parser.parse_args(argv)
    if (args.apply and not args.run) or (args.forget and not args.apply):
        parser.error("--apply requires --run; --forget also requires --apply")
    try:
        root = Path(command("git", "rev-parse", "--show-toplevel")).resolve()
        store = registry_path(root)
        if not store.exists():
            print("No registered test runs. No changes made.")
            return 0
        private(store, directory=True)
        if args.run:
            if str(uuid.UUID(args.run)) != args.run:
                raise Unsafe("invalid run UUID")
            paths = [store / (args.run + ".json")]
        else:
            paths = sorted(store.glob("*.json"))
        failed = False
        for path in paths:
            run = Run.open(path, root, apply=args.apply)
            try:
                print(f"Run {run.data['run']}: test={run.data['test']} stage={run.data['stage']} exit={run.data['exit']} cleanup={run.data['outcome']}")
                print(f"  registered scratch: {run.data['scratch']}")
                result = run.cleanup(apply=args.apply)
                for outcome, messages in result.items():
                    for message in messages:
                        print(f"  {outcome}: {message}")
                failed |= bool(result["failed"]) or len(result["retained"]) > 1
                if args.forget and not failed:
                    run.forget()
            finally:
                run.close()
        print("Apply complete; review retained/failed outcomes." if args.apply else "Preview only; no changes made.")
        return int(failed)
    except (Unsafe, OSError, ValueError):
        print("Recovery refused: record, worktree, lease, or daemon could not be verified. No broader cleanup attempted.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
