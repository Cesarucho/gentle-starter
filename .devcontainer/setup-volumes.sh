#!/usr/bin/env bash
# setup-volumes.sh — volume-aware install repair.
#
# Sourced by setup.sh during the devcontainer postCreate hook. Parses
# the bind mounts declared in docker-compose.yml and re-runs the
# install scripts that own each target with DEVCONTAINER_PHASE=runtime.
# Each install script is idempotent (uses lib/common.sh's
# devcontainer_has_cmd guard at the top), so a re-run on a populated
# volume is a no-op.
#
# The contract has three pieces, and they all have to agree for the
# repair to fire:
#
#   1. The bind mount itself: declared in
#      .devcontainer/docker-compose.yml as a string under
#      services.container-svc.volumes, e.g.
#        - ../env/.postgresql:/home/ubuntu/.postgresql
#
#   2. The target-to-script mapping: a case in
#      compose_target_to_install_scripts() below, e.g.
#        "${HOME}/.postgresql")
#            scripts_ref+=("40-data-postgresql")
#            ;;
#
#   3. The install script itself: lives in
#      .devcontainer/install/available/40-data-postgresql.sh and
#      (for default activation) is linked from
#      .devcontainer/install/02-enabled/.
#
# To add a new stateful volume (e.g. PostgreSQL data dir):
#   a. Add the bind mount in docker-compose.yml.
#   b. Add a case for the new target path in
#      compose_target_to_install_scripts() below.
#   c. Add the install script in install/available/.
#   d. Link it from install/02-enabled/ if it should run by default.
#
# Note: this file is meant to be sourced by setup.sh. It relies on
# WORKSPACE_DIR, HOME, and UID being set by the caller. Running it
# directly will not work.

# Emit "source|target" pairs, one per line, for each bind mount in
# docker-compose.yml with both source and target defined.
resolve_compose_volume_targets() {
	local compose_file="${WORKSPACE_DIR}/.devcontainer/docker-compose.yml"
	local vol
	local src
	local tgt

	while IFS= read -r vol; do
		# Skip empty lines
		[ -z "${vol// /}" ] && continue

		# The short-form volume entry is a string like
		# "../env/.pi:/home/ubuntu/.pi[:ro|:rw]". Strip the YAML
		# list prefix and split on the first colon.
		vol="${vol#"${vol%%[![:space:]]*}"}" # leading whitespace
		vol="${vol#- }"                      # YAML list marker
		vol="${vol#-}"                       # YAML list marker (no space)

		if [[ "${vol}" == *:* ]]; then
			src="${vol%%:*}"
			tgt="${vol#*:}"
			tgt="${tgt%%:*}" # strip optional :ro/:rw mode

			# Bind mounts have a non-empty source.
			if [ -n "${src}" ] && [ -n "${tgt}" ]; then
				printf '%s|%s\n' "${src}" "${tgt}"
			fi
		fi
	done < <(yq -r '.services."container-svc".volumes[]' "${compose_file}" 2>/dev/null || true)
}

# Map a container-side target path to the install script base names
# (without the .sh extension) that own that volume.
compose_target_to_install_scripts() {
	local target="$1"
	local -n scripts_ref="$2"

	scripts_ref=()
	case "${target}" in
	"${HOME}/.pi" | "/home/${UID}/.pi")
		scripts_ref+=("30-ai-pi-coding" "30-ai-pi-gentle")
		;;
	"${HOME}/.engram" | "/home/${UID}/.engram")
		scripts_ref+=("30-ai-engram")
		;;
	"${HOME}/.local" | "/home/${UID}/.local")
		scripts_ref+=("30-ai-engram")
		;;
	esac
}

# Iterate over bind-mount volume targets from docker-compose.yml and
# run the install scripts that own each target, with
# DEVCONTAINER_PHASE=runtime. Each script is idempotent: it skips
# itself when the tool is already installed, so a re-run on a
# populated volume is a no-op.
repair_installed_volumes() {
	local install_root="${WORKSPACE_DIR}/.devcontainer/install/available"
	local target_path
	local scripts=()
	local script
	local script_path

	while IFS='|' read -r _ target_path; do
		compose_target_to_install_scripts "${target_path}" scripts

		for script in "${scripts[@]}"; do
			script_path="${install_root}/${script}.sh"
			if [ ! -f "${script_path}" ]; then
				continue
			fi
			echo "Volume repair: ${target_path} -> ${script}.sh"
			DEVCONTAINER_PHASE=runtime bash "${script_path}"
		done
	done < <(resolve_compose_volume_targets)
}
