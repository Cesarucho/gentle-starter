#!/usr/bin/env python3
"""Explicit Docker build fixture with the same durable recovery as lifecycle tests."""

from pathlib import Path
import signal
import sys

from test_resources import LABEL, Run, Unsafe


def main(root, parent):
    owner = Run.create(root, parent)
    print(f"Image-contract recovery run: {owner.data['run']}", flush=True)
    failure = False
    was_interrupted = False
    def interrupted(signum, _frame):
        nonlocal was_interrupted
        was_interrupted = True
        raise Unsafe("image fixture interrupted")
    previous = {sig: signal.signal(sig, interrupted) for sig in (signal.SIGINT, signal.SIGTERM)}
    try:
        owner.arm()
        owner.produce(["docker", "build", "--quiet", "--target", "devcontainer-version-contract",
                       "--build-arg", "ENGRAM_VERSION=9.9.9", "--label", f"{LABEL}={owner.data['run']}",
                       "--tag", owner.data["tag"], str(root / ".devcontainer")],
                      root, owner.docker.env, "build")
        owner.stage("verify")
        template = '{{range .Config.Env}}{{if eq . "ENGRAM_VERSION=9.9.9"}}verified{{end}}{{end}}'
        if owner.docker("image", "inspect", "--format", template, owner.data["tag"]) != "verified":
            raise Unsafe("runtime build argument assertion failed")
        owner.finish("passed")
    except (Unsafe, OSError):
        failure = True
        try:
            owner.finish("interrupted" if was_interrupted else "failed")
        except (Unsafe, OSError):
            pass
        print("Image contract failed; bounded stage/status retained, raw output withheld.", file=sys.stderr)
    finally:
        for sig in previous:
            signal.signal(sig, signal.SIG_IGN)
        result = owner.cleanup(apply=True)
        owner.close()
        for sig, handler in previous.items():
            signal.signal(sig, handler)
    for outcome, messages in result.items():
        for message in messages:
            print(f"{outcome}: {message}")
    return int(failure or bool(result["failed"]) or len(result["retained"]) > 1)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: image-contract.py SOURCE_ROOT SCRATCH_PARENT")
    sys.exit(main(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()))
