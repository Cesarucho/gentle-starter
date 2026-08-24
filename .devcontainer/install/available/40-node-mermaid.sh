#!/usr/bin/env bash
#
# 40-node-mermaid.sh — install Mermaid CLI and its headless browser.
#
# Provides the `mmdc` command. Requires Node.js/npm, normally provided by
# 20-runtime-node.sh when enabled.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

: "${MERMAID_CLI_VERSION:=11.16.0}"
: "${UID_NAME:=ubuntu}"

if ! devcontainer_has_cmd npm; then
	devcontainer_log_error "npm is required to install Mermaid CLI"
	devcontainer_log_error "Enable 20-runtime-node.sh before this script"
	exit 1
fi

user_home="$(getent passwd "${UID_NAME}" | cut -d: -f6)"
if [ -z "${user_home}" ]; then
	devcontainer_log_error "User not found: ${UID_NAME}"
	exit 1
fi

# Keep the managed binary outside ubuntu's PATH so /usr/local/bin/mmdc is the
# single public entry point and always applies the container-safe config.
mermaid_prefix="/opt/mermaid-cli"
mermaid_cli="${mermaid_prefix}/bin/mmdc"
puppeteer_config="/etc/mermaid-cli/puppeteer.json"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
printf 'graph TD; A-->B\n' >"${TMP_DIR}/smoke.mmd"
devcontainer_run_as_root chown -R "${UID_NAME}:${UID_NAME}" "${TMP_DIR}"

render_smoke() {
	rm -f "${TMP_DIR}/smoke.svg"
	sudo -H -u "${UID_NAME}" mmdc \
		-i "${TMP_DIR}/smoke.mmd" \
		-o "${TMP_DIR}/smoke.svg" >/dev/null 2>&1 &&
		[ -s "${TMP_DIR}/smoke.svg" ]
}

if devcontainer_has_cmd mmdc && render_smoke; then
	devcontainer_log_info "Mermaid CLI already render-ready: $(mmdc --version)"
	exit 0
fi

devcontainer_log_info "Installing Mermaid browser dependencies"
devcontainer_run_as_root apt-get update
devcontainer_run_as_root apt-get install -y --no-install-recommends \
	libasound2t64 \
	libatk-bridge2.0-0t64 \
	libgbm1 \
	libnss3 \
	libxcomposite1 \
	libxdamage1 \
	libxfixes3 \
	libxkbcommon0 \
	libxrandr2

devcontainer_log_info "Installing @mermaid-js/mermaid-cli@${MERMAID_CLI_VERSION} as ${UID_NAME}"
devcontainer_run_as_root install -d -o "${UID_NAME}" -g "${UID_NAME}" "${mermaid_prefix}"
sudo -H -u "${UID_NAME}" npm install -g \
	--prefix "${mermaid_prefix}" \
	--ignore-scripts=false \
	--foreground-scripts \
	"@mermaid-js/mermaid-cli@${MERMAID_CLI_VERSION}"

if [ ! -x "${mermaid_cli}" ]; then
	devcontainer_log_error "Mermaid CLI install failed: ${mermaid_cli} not found"
	exit 1
fi

printf '%s\n' '{"args":["--no-sandbox"]}' >"${TMP_DIR}/puppeteer.json"
cat >"${TMP_DIR}/mmdc" <<EOF
#!/usr/bin/env bash
set -euo pipefail
for argument in "\$@"; do
	case "\${argument}" in
	-p | --puppeteerConfigFile | --puppeteerConfigFile=*)
		exec "${mermaid_cli}" "\$@"
		;;
	esac
done
exec "${mermaid_cli}" --puppeteerConfigFile "${puppeteer_config}" "\$@"
EOF

devcontainer_run_as_root install -d -m 0755 "$(dirname "${puppeteer_config}")"
devcontainer_run_as_root install -m 0644 "${TMP_DIR}/puppeteer.json" "${puppeteer_config}"
devcontainer_run_as_root install -m 0755 "${TMP_DIR}/mmdc" /usr/local/bin/mmdc

if ! render_smoke; then
	devcontainer_log_error "Mermaid CLI install failed: functional SVG render check failed"
	exit 1
fi

devcontainer_log_info "Mermaid CLI installed and render-checked: $(mmdc --version)"
