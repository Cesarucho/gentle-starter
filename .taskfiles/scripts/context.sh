#!/usr/bin/env bash
# context.sh — shared context detection helpers for tasks.
# Source this file from any task script that needs to know
# whether it's running on the host or inside the devcontainer.

# Returns 0 (success) if running inside the devcontainer.
is_container() {
	[ "${DEVCONTAINER:-}" = "true" ] ||
		[ "${REMOTE_CONTAINERS:-}" = "true" ] ||
		{ [ -f /.dockerenv ] && [ -f "${HOME}/.devcontainer/devcontainer.json" ]; }
}

# Returns 0 (success) if running on the host (not inside the container).
is_host() {
	! is_container
}

# Guard: abort with a friendly message if running in the wrong context.
# Usage: require_host "task name"  or  require_container "task name"
require_host() {
	if is_container; then
		echo "[skip] $1 must be run on the host, not inside the container." >&2
		echo "[skip] Run this from your terminal on the host machine." >&2
		exit 0
	fi
}

require_container() {
	if is_host; then
		echo "[skip] $1 must be run inside the devcontainer." >&2
		echo "[skip] Connect to the container first: task container:connect" >&2
		exit 0
	fi
}
