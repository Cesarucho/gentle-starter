# Dedicated rcfile for task container:connect; never installed as a global hook.
if [[ -r ${HOME}/.bashrc ]]; then
	# shellcheck source=/dev/null
	source "${HOME}/.bashrc" || :
fi

gentle_connect_welcome() (
	[[ $- == *i* && -t 0 && -t 1 ]] || return 0
	printf 'Welcome to Gentle Starter.\n'
	local script_dir workspace matches status line algorithm blob conflict=0 revoked=0
	local -A key_blobs=()
	script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || return 0
	workspace="$(cd -- "${script_dir}/../.." && pwd)" || return 0
	if ! python3 "${script_dir}/compose-manifest.py" ssh-agent "${workspace}"; then
		printf 'SSH onboarding unavailable: verify the applied optional agent override.\n'
		return 0
	fi
	if [[ ${SSH_AUTH_SOCK:-} != /ssh-agent || ! -S /ssh-agent ]]; then
		printf 'SSH onboarding unavailable: expected local agent socket /ssh-agent.\n'
		return 0
	fi
	printf 'Agent socket exists; responsiveness and loaded keys have not been checked.\n'
	if [[ -e ${HOME}/.ssh/known_hosts || -L ${HOME}/.ssh/known_hosts ]]; then
		if [[ ! -f ${HOME}/.ssh/known_hosts || ! -r ${HOME}/.ssh/known_hosts ]]; then
			printf 'GitHub known_hosts lookup unavailable; inspect the file manually.\n'
			return 0
		fi
		matches="$(ssh-keygen -F github.com -f "${HOME}/.ssh/known_hosts" 2>/dev/null)"
		status=$?
		if ((status > 1)) || { ((status == 1)) && [[ -n ${matches} ]]; }; then
			printf 'GitHub known_hosts lookup failed; inspect the file manually.\n'
			return 0
		fi
		if ((status == 0)); then
			while IFS= read -r line; do
				[[ ${line} == \#* || -z ${line} ]] && continue
				[[ ${line} == '@revoked '* ]] && revoked=1
				if [[ ${line} == @* ]]; then
					read -r _ _ algorithm blob _ <<<"${line}"
				else
					read -r _ algorithm blob _ <<<"${line}"
				fi
				[[ -n ${algorithm} && -n ${blob} ]] || continue
				[[ -n ${key_blobs[${algorithm}]:-} && ${key_blobs[${algorithm}]} != "${blob}" ]] && conflict=1
				key_blobs[${algorithm}]="${blob}"
			done <<<"${matches}"
			printf 'GitHub known_hosts entry present; presence does not establish valid trust.\n'
			((revoked)) && printf 'WARNING: revoked GitHub entry; resolve manually, never bypass revocation.\n'
			((conflict)) && printf 'WARNING: multiple differing GitHub records; inspect possible conflicts manually.\n'
			return 0
		fi
	fi
	printf 'GitHub host trust is missing. Verify fingerprints before accepting manually:\n'
	printf '  ssh -o StrictHostKeyChecking=ask -T git@github.com\n'
	printf '  https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints\n'
)

gentle_connect_welcome || :
unset -f gentle_connect_welcome
