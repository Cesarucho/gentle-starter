#!/usr/bin/env bash
# Git adapter for the transport-neutral repository status port.

GIT_REPOSITORY_STATUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.taskfiles/scripts/starter-lib/contracts/repository-status-port.sh
source "${GIT_REPOSITORY_STATUS_DIR}/../contracts/repository-status-port.sh"

git_repository_status_inspect() {
	local project_root="$1" physical_root git_root status clean=true
	physical_root="$(cd -P -- "${project_root}" 2>/dev/null && pwd)" || return 1
	git_root="$(GIT_OPTIONAL_LOCKS=0 git -C "${physical_root}" rev-parse --show-toplevel 2>/dev/null)" || {
		jq -cn '{schema:"gentle-starter.repository-status/v1",is_repository:false,root_matches:false,clean:false}'
		return
	}
	git_root="$(cd -P -- "${git_root}" && pwd)" || return 1
	if [ "${git_root}" != "${physical_root}" ]; then
		jq -cn '{schema:"gentle-starter.repository-status/v1",is_repository:true,root_matches:false,clean:false}'
		return
	fi
	status="$(GIT_OPTIONAL_LOCKS=0 git -C "${physical_root}" status --porcelain=v1 --untracked-files=all)" || return 1
	[ -n "${status}" ] && clean=false
	jq -cn --argjson clean "${clean}" \
		'{schema:"gentle-starter.repository-status/v1",is_repository:true,root_matches:true,clean:$clean}'
}
