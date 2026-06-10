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
set -euo pipefail

export SDKMAN_DIR="${HOME}/.sdkman"

curl -s "https://get.sdkman.io" | bash

# shellcheck source=/dev/null
source "${SDKMAN_DIR}/bin/sdkman-init.sh"

sdk install java "${JAVA_VERSION}"
java --version
EOF

chown -R "${UID_NAME}:${UID_NAME}" "${user_home}/.sdkman"
