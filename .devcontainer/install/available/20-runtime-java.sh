#!/usr/bin/env bash
#
# 20-runtime-java.sh — install Java via SDKMAN, run as the devcontainer user.
#
# Mirrors .devcontainer/scripts/12-install-java.sh with the common.sh
# helpers.
#
# CRITICAL: the inner `sudo -H -u` heredoc uses `set -eo pipefail`
# WITHOUT `-u`. SDKMAN's init script binds and reads
# `SDKMAN_CANDIDATES_API` without a default, so `set -u` aborts with
# "unbound variable" the moment the script is sourced. This is the
# only Fasen 7 script that needs the no-`u` carve-out.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${UID_NAME:=ubuntu}"
: "${JAVA_VERSION:=25-tem}"

if devcontainer_has_cmd java; then
    devcontainer_log_info "java already installed: $(java --version | head -1)"
    exit 0
fi

user_home="$(getent passwd "${UID_NAME}" | cut -d: -f6)"
if [ -z "${user_home}" ]; then
    devcontainer_log_error "User not found: ${UID_NAME}"
    exit 1
fi

devcontainer_log_info "Installing Java ${JAVA_VERSION} via SDKMAN as ${UID_NAME}"
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

devcontainer_log_info "Re-chowning ${user_home}/.sdkman to ${UID_NAME}"
devcontainer_run_as_root chown -R "${UID_NAME}:${UID_NAME}" "${user_home}/.sdkman"

devcontainer_log_info "Symlinking java binaries to /usr/local/bin"
java_bin_dir="${user_home}/.sdkman/candidates/java/current/bin"
for command_name in jar java javac javadoc jshell keytool; do
    if [ -x "${java_bin_dir}/${command_name}" ]; then
        devcontainer_run_as_root ln -sfn "${java_bin_dir}/${command_name}" "/usr/local/bin/${command_name}"
    fi
done

devcontainer_log_info "java installed: $(java --version | head -1)"
