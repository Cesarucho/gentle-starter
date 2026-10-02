#!/usr/bin/env bash
# Optional image-owned Shell; never provisions a user home during installation.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"
devcontainer_load_tool_versions
version="${LOCK_GENTLE_SHELL_VERSION:?missing LOCK_GENTLE_SHELL_VERSION}"
integrity="${LOCK_GENTLE_SHELL_INTEGRITY:?missing LOCK_GENTLE_SHELL_INTEGRITY}"
private_version="${LOCK_GENTLE_SHELL_GENTLE_AI_VERSION:?missing LOCK_GENTLE_SHELL_GENTLE_AI_VERSION}"
pi_pin="${LOCK_PI_CODING_AGENT_VERSION:?missing LOCK_PI_CODING_AGENT_VERSION}"
[[ "${pi_pin}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
[ "$(printf '%s\n%s\n' 0.99.1 "${pi_pin}" | sort -V | head -n 1)" = 0.99.1 ] || exit 1
for key in LOCK_GENTLE_SHELL_SHA256_AMD64 LOCK_GENTLE_SHELL_SHA256_ARM64 LOCK_GENTLE_SHELL_BINARY_SHA256_AMD64 LOCK_GENTLE_SHELL_BINARY_SHA256_ARM64; do
	[[ "${!key:-}" =~ ^[0-9a-f]{64}$ ]] || {
		devcontainer_log_error "Missing or invalid ${key}"
		exit 1
	}
done
[[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "${private_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "${integrity}" =~ ^sha512-[A-Za-z0-9+/]{86}==$ ]] || exit 1
if [ "${1:-}" = --print-version-policy ]; then
	printf 'GENTLE_SHELL_VERSION=%s\nGENTLE_SHELL_GENTLE_AI_VERSION=%s\n' "${version}" "${private_version}"
	exit 0
fi
if devcontainer_is_runtime; then
	devcontainer_log_info "Gentle Shell is image-owned; rebuild to install or repair it."
	exit 0
fi
[ "$(uname -s)" = Linux ] || exit 1
arch="$(devcontainer_arch)"
devcontainer_require_cmd npm "Enable core Node before Gentle Shell."
devcontainer_require_cmd node "Enable core Node before Gentle Shell."
devcontainer_require_cmd pi "Enable 3030-ai-pi-coding.sh before Gentle Shell."
node -e 'if (process.versions.node.localeCompare("22.19.0", undefined, {numeric:true}) < 0) process.exit(1)'
pi_root="$(devcontainer_run_as_root npm root --global)/@earendil-works/pi-coding-agent"
node "${SCRIPT_DIR}/../lib/gentle-shell-bundle.mjs" pi "${pi_root}" "${pi_pin}" >/dev/null
: "${GENTLE_SHELL_INSTALL_ROOT:=/opt/gentle-shell}"
: "${GENTLE_SHELL_BIN:=/usr/local/bin/gentle-shell}"
destination="${GENTLE_SHELL_INSTALL_ROOT}/${version}"
tmp="$(mktemp -d)"
stage=""
cleanup() {
	rm -rf -- "${tmp}"
	[ -z "${stage}" ] || devcontainer_run_as_root rm -rf -- "${stage}"
}
trap cleanup EXIT
archive_key="LOCK_GENTLE_SHELL_SHA256_${arch^^}"
binary_key="LOCK_GENTLE_SHELL_BINARY_SHA256_${arch^^}"
asset="gentle-ai_${private_version}_linux_${arch}.tar.gz"
manifest="${tmp}/manifest.json"
node -e 'const [version,asset,assetSha256,binarySha256]=process.argv.slice(1); console.log(JSON.stringify({version,asset,assetSha256,binarySha256}))' \
	"${private_version}" "${asset}" "${!archive_key}" "${!binary_key}" >"${manifest}"
verify() {
	node "${SCRIPT_DIR}/../lib/gentle-shell-bundle.mjs" verify "$1/lib/node_modules/gentle-pi" "${version}" "${manifest}" "${pi_pin}"
}
if ! verify "${destination}" 2>/dev/null; then
	if [ -e "${destination}" ] || [ -L "${destination}" ]; then
		devcontainer_log_error "Invalid existing ${destination}; remove that image-owned version explicitly before rebuilding."
		exit 1
	fi
	devcontainer_fetch "https://registry.npmjs.org/gentle-pi/-/gentle-pi-${version}.tgz" "${tmp}/package.tgz"
	python3 "${SCRIPT_DIR}/../lib/gentle-shell-archive.py" package "${tmp}/package.tgz" "${integrity}" "${tmp}/unpacked"
	node "${SCRIPT_DIR}/../lib/gentle-shell-bundle.mjs" pins "${tmp}/unpacked/package" "${version}" >"${tmp}/pins.json"
	node -e 'const fs=require("fs"); const [pins,manifest,arch]=process.argv.slice(1); if(JSON.stringify(JSON.parse(fs.readFileSync(pins))[arch])!==JSON.stringify(JSON.parse(fs.readFileSync(manifest)))) process.exit(1)' "${tmp}/pins.json" "${manifest}" "${arch}"
	devcontainer_fetch "https://github.com/Gentleman-Programming/gentle-ai/releases/download/v${private_version}/${asset}" "${tmp}/private.tar.gz"
	actual="$(python3 "${SCRIPT_DIR}/../lib/gentle-shell-archive.py" binary "${tmp}/private.tar.gz" "${!archive_key}" "${tmp}/gentle-ai")"
	[ "${actual}" = "${!binary_key}" ] || {
		devcontainer_log_error "Private binary integrity mismatch"
		exit 1
	}
	devcontainer_run_as_root install -d -m 0755 -- "${GENTLE_SHELL_INSTALL_ROOT}"
	stage="$(devcontainer_run_as_root mktemp -d "${GENTLE_SHELL_INSTALL_ROOT}/.stage.XXXXXX")"
	devcontainer_run_as_root chmod 0755 "${stage}"
	# The real managed Pi loader supplies its own API; never install peer copies.
	devcontainer_run_as_root npm install --global --prefix "${stage}" --legacy-peer-deps --ignore-scripts --no-audit --no-fund "${tmp}/package.tgz"
	devcontainer_run_as_root chmod -R a+rX "${stage}"
	bundle="${stage}/lib/node_modules/gentle-pi/.gentle-ai/v${private_version}"
	devcontainer_run_as_root install -d -m 0755 "${stage}/lib/node_modules/gentle-pi/.gentle-ai" "${bundle}"
	devcontainer_run_as_root install -m 0755 "${tmp}/gentle-ai" "${bundle}/gentle-ai"
	devcontainer_run_as_root install -m 0644 "${manifest}" "${bundle}/integrity.json"
	verify "${stage}"
	devcontainer_run_as_root mv -- "${stage}" "${destination}"
	stage=""
fi
# Publish only after complete package/private verification; never run native setup.
node -e 'const fs=require("fs"); console.log(JSON.stringify({version:process.argv[1],manifest:JSON.parse(fs.readFileSync(process.argv[2])),piVersion:process.argv[3],piRoot:process.argv[4]}))' "${version}" "${manifest}" "${pi_pin}" "${pi_root}" >"${tmp}/bundle.json"
devcontainer_run_as_root install -m 0644 "${tmp}/bundle.json" "${destination}/bundle.json"
devcontainer_run_as_root install -m 0644 "${SCRIPT_DIR}/../lib/gentle-shell-bundle.mjs" "${destination}/gentle-shell-bundle.mjs"
devcontainer_run_as_root install -m 0644 "${SCRIPT_DIR}/../lib/gentle-shell-provision.mjs" "${destination}/gentle-shell-provision.mjs"
devcontainer_run_as_root install -m 0755 "${SCRIPT_DIR}/../lib/gentle-shell-launcher.mjs" "${destination}/gentle-shell-launcher.mjs"
[ ! -d "${GENTLE_SHELL_BIN}" ] || exit 1
devcontainer_run_as_root ln -sfn -- "${destination}/gentle-shell-launcher.mjs" "${GENTLE_SHELL_BIN}"
devcontainer_log_info "Gentle Shell ${version} installed with policy-managed Pi; runtime provisioning is repository-controlled."
