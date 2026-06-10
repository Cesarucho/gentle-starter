#!/usr/bin/env bash
set -euo pipefail

: "${UID_NAME:=ubuntu}"
: "${JAVA_VERSION:=25-tem}"

user_home="$(getent passwd "${UID_NAME}" | cut -d: -f6)"
if [ -z "${user_home}" ]; then
	echo "User not found: ${UID_NAME}" >&2
	exit 1
fi

sudo -H -u "${UID_NAME}" env JAVA_VERSION="${JAVA_VERSION}" bash <<'EOF'
# SDKMAN's scripts are not safe with Bash nounset (`set -u`).
set -eo pipefail

export SDKMAN_DIR="${HOME}/.sdkman"

curl -s "https://get.sdkman.io" | bash

mkdir -p "${SDKMAN_DIR}/etc"
touch "${SDKMAN_DIR}/etc/config"
if grep -q '^sdkman_auto_answer=' "${SDKMAN_DIR}/etc/config"; then
	sed -i 's/^sdkman_auto_answer=.*/sdkman_auto_answer=true/' "${SDKMAN_DIR}/etc/config"
else
	printf '\nsdkman_auto_answer=true\n' >>"${SDKMAN_DIR}/etc/config"
fi

# shellcheck source=/dev/null
source "${SDKMAN_DIR}/bin/sdkman-init.sh"

sdk install java "${JAVA_VERSION}" || sdk default java "${JAVA_VERSION}"
sdk default java "${JAVA_VERSION}"
java --version
EOF

run_as_root() {
	if [ "$(id -u)" -eq 0 ]; then
		"$@"
	else
		sudo "$@"
	fi
}

run_as_root chown -R "${UID_NAME}:${UID_NAME}" "${user_home}/.sdkman"

java_bin_dir="${user_home}/.sdkman/candidates/java/current/bin"
for command_name in jar java javac javadoc jshell keytool; do
	if [ -x "${java_bin_dir}/${command_name}" ]; then
		run_as_root ln -sfn "${java_bin_dir}/${command_name}" "/usr/local/bin/${command_name}"
	fi
done
