#!/usr/bin/env bash
#
# 2210-cli-plantuml.sh — install PlantUML from the official Maven artifact.
#
# Installs the versioned PlantUML jar plus a `plantuml` wrapper. Requires Java,
# normally provided by 2200-runtime-java.sh when enabled.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_load_tool_versions

: "${PLANTUML_VERSION:=${LOCK_PLANTUML_VERSION:?missing LOCK_PLANTUML_VERSION}}"
: "${PLANTUML_SHA256:=${LOCK_PLANTUML_SHA256:?missing LOCK_PLANTUML_SHA256}}"

if [ "${1:-}" = "--print-version-policy" ]; then
	printf 'PLANTUML_VERSION=%s\n' "${PLANTUML_VERSION}"
	printf 'PLANTUML_SHA256=%s\n' "${PLANTUML_SHA256}"
	exit 0
fi
: "${PLANTUML_INSTALL_DIR:=/usr/local/share/plantuml}"
: "${PLANTUML_BIN_DIR:=/usr/local/bin}"

plantuml_version_line() {
	local output
	output="$(plantuml -version)"
	printf '%s\n' "${output%%$'\n'*}"
}

if devcontainer_has_cmd plantuml; then
	devcontainer_log_info "PlantUML already installed: $(plantuml_version_line)"
	exit 0
fi

devcontainer_require_cmd java "Enable 2200-runtime-java.sh before PlantUML." || exit 1

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

JAR_NAME="plantuml-${PLANTUML_VERSION}.jar"
JAR_PATH="${TMP_DIR}/${JAR_NAME}"
MAVEN_URL="https://repo.maven.apache.org/maven2/net/sourceforge/plantuml/plantuml/${PLANTUML_VERSION}"

devcontainer_log_info "Downloading PlantUML ${PLANTUML_VERSION}"
devcontainer_fetch "${MAVEN_URL}/${JAR_NAME}" "${JAR_PATH}"
devcontainer_verify_sha256 "${JAR_PATH}" "${PLANTUML_SHA256}"

devcontainer_run_as_root mkdir -p "${PLANTUML_INSTALL_DIR}"
devcontainer_run_as_root install -m 0644 "${JAR_PATH}" \
	"${PLANTUML_INSTALL_DIR}/plantuml.jar"

WRAPPER_PATH="${TMP_DIR}/plantuml"
cat >"${WRAPPER_PATH}" <<EOF
#!/usr/bin/env bash
exec java -jar "${PLANTUML_INSTALL_DIR}/plantuml.jar" "\$@"
EOF
devcontainer_run_as_root install -m 0755 "${WRAPPER_PATH}" \
	"${PLANTUML_BIN_DIR}/plantuml"

if ! devcontainer_has_cmd plantuml; then
	devcontainer_log_error "PlantUML install failed: wrapper not on PATH"
	exit 1
fi

devcontainer_log_info "PlantUML installed: $(plantuml_version_line)"
