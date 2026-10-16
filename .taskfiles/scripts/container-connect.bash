# Dedicated rcfile for task container:connect; never installed as a global hook.
if [[ -r ${HOME}/.bashrc ]]; then
	# shellcheck source=/dev/null
	source "${HOME}/.bashrc" || :
fi

gentle_connect_welcome() (
	[[ $- == *i* && -t 0 && -t 1 ]] || return 0
	local welcome_level=${WELCOME_LOG_LEVEL-info}
	case ${welcome_level} in
	info | warn) ;;
	off) return 0 ;;
	*)
		printf '[warn] Invalid WELCOME_LOG_LEVEL; expected info, warn, or off. Using info.\n'
		welcome_level=info
		;;
	esac
	[[ ${welcome_level} == info ]] && printf '[info] Welcome to Gentle Starter.\n'
	local script_dir workspace matches status line algorithm blob conflict=0 revoked=0
	local -A key_blobs=()
	script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || return 0
	workspace="$(cd -- "${script_dir}/../.." && pwd)" || return 0
	if ! python3 "${script_dir}/compose-manifest.py" ssh-agent "${workspace}"; then
		printf '[warn] SSH onboarding unavailable: verify the applied optional agent override.\n'
		return 0
	fi
	if [[ ${SSH_AUTH_SOCK:-} != /ssh-agent || ! -S /ssh-agent ]]; then
		printf '[warn] SSH onboarding unavailable: expected local agent socket /ssh-agent.\n'
		return 0
	fi
	[[ ${welcome_level} == info ]] && printf '[info] Agent socket exists; responsiveness and loaded keys have not been checked.\n'
	if [[ -e ${HOME}/.ssh/known_hosts || -L ${HOME}/.ssh/known_hosts ]]; then
		if [[ ! -f ${HOME}/.ssh/known_hosts || ! -r ${HOME}/.ssh/known_hosts ]]; then
			printf '[warn] GitHub known_hosts lookup unavailable; inspect the file manually.\n'
			return 0
		fi
		if ! command -v ssh-keygen >/dev/null 2>&1; then
			printf '[warn] GitHub known_hosts lookup unavailable: ssh-keygen command not found.\n'
			return 0
		fi
		matches="$(ssh-keygen -F github.com -f "${HOME}/.ssh/known_hosts" 2>/dev/null)"
		status=$?
		if ((status > 1)) || { ((status == 1)) && [[ -n ${matches} ]]; }; then
			printf '[warn] GitHub known_hosts lookup failed; inspect the file manually.\n'
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
			[[ ${welcome_level} == info ]] && printf '[info] GitHub known_hosts entry present; presence does not establish valid trust.\n'
			((revoked)) && printf '[warn] revoked GitHub entry; resolve manually, never bypass revocation.\n'
			((conflict)) && printf '[warn] multiple differing GitHub records; inspect possible conflicts manually.\n'
			return 0
		fi
	fi
	printf '[warn] GitHub host trust is missing. Verify fingerprints before accepting manually:\n'
	printf '  ssh -o StrictHostKeyChecking=ask -T git@github.com\n'
	printf '  https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints\n'
)

gentle_connect_welcome || :
unset -f gentle_connect_welcome
