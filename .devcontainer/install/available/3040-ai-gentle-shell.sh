#!/usr/bin/env bash
# Optional native npm installation; user configuration belongs to postCreate.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"
devcontainer_load_tool_versions
version="${LOCK_GENTLE_SHELL_VERSION:?missing LOCK_GENTLE_SHELL_VERSION}"
integrity="${LOCK_GENTLE_SHELL_INTEGRITY:?missing LOCK_GENTLE_SHELL_INTEGRITY}"
[[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "${integrity}" =~ ^sha512-[A-Za-z0-9+/]{86}==$ ]] || exit 1
if [ "${1:-}" = --print-version-policy ]; then
	printf 'GENTLE_SHELL_VERSION=%s\n' "${version}"
	exit 0
fi
if devcontainer_is_runtime; then
	devcontainer_log_info "Gentle Shell is image-owned; rebuild to install or repair it."
	exit 0
fi
[ "$(uname -s)" = Linux ] || exit 1
devcontainer_arch >/dev/null
devcontainer_require_cmd npm "Enable core Node before Gentle Shell."
devcontainer_require_cmd node "Enable core Node before Gentle Shell."
node -e 'if (process.versions.node.localeCompare("22.19.0", undefined, {numeric:true}) < 0) process.exit(1)'
tmp="$(mktemp -d)"
trap 'rm -rf -- "${tmp}"' EXIT
devcontainer_fetch "https://registry.npmjs.org/gentle-pi/-/gentle-pi-${version}.tgz" "${tmp}/package.tgz"
# Check the same local bytes npm will install, before any lifecycle script runs.
node - "${tmp}/package.tgz" "${integrity}" <<'JS'
const fs = require('node:fs');
const crypto = require('node:crypto');
const actual = 'sha512-' + crypto.createHash('sha512').update(fs.readFileSync(process.argv[2])).digest('base64');
if (actual !== process.argv[3]) throw new Error('Gentle Shell package SRI mismatch');
JS
devcontainer_run_as_root npm install --global --ignore-scripts=false --no-audit --no-fund "${tmp}/package.tgz"
package_root="$(devcontainer_run_as_root npm root --global)/gentle-pi"
# Inspect metadata, not the mutating native CLI. npm owns the native bin link.
devcontainer_run_as_root node - "${package_root}" "${version}" <<'JS'
const fs = require('node:fs');
const path = require('node:path');
const root = process.argv[2];
if (!path.isAbsolute(root) || fs.lstatSync(root).isSymbolicLink()) throw new Error('Invalid global package root');
const pkg = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
if (pkg.name !== 'gentle-pi' || pkg.version !== process.argv[3] || pkg.bin?.['gentle-shell'] !== 'bin/gentle-shell.mjs') throw new Error('Unexpected native Shell package');
JS
# Upstream postinstall creates owner-only private files; make this package readable
# and executable by ubuntu without changing global npm ownership or user state.
devcontainer_run_as_root chmod -R a+rX "${package_root}"
devcontainer_log_info "Gentle Shell ${version} installed with native npm scripts and launcher."
