#!/usr/bin/env bash
set -euo pipefail

# Resolve the versioned installation, never the npm shim's HOME cache/fallback.
root="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
case "$(uname -s):$(uname -m)" in
Linux:x86_64 | Linux:aarch64 | Linux:arm64) ;;
*)
	printf 'CodeGraph supports Linux amd64 and arm64 only.\n' >&2
	exit 1
	;;
esac
bundle="${root}/bundle"
if [ ! -x "${bundle}/node" ] || [ ! -x "${bundle}/bin/codegraph" ]; then
	printf 'CodeGraph platform bundle is missing; rebuild the image.\n' >&2
	exit 1
fi

# Tool-scoped defaults also cover CLI use without the optional Compose mount.
export CODEGRAPH_TELEMETRY="${CODEGRAPH_TELEMETRY:-0}"
export CODEGRAPH_NO_UPDATE_CHECK="${CODEGRAPH_NO_UPDATE_CHECK:-1}"
export CODEGRAPH_NO_DOWNLOAD=1
exec "${bundle}/bin/codegraph" "$@"
