#!/usr/bin/env bash
#
# 10-system.sh — install base apt packages used by every devcontainer phase.
#
# Mirrors the legacy .devcontainer/scripts/01-install-apt.sh with the
# common.sh helpers. Runs as part of core/ during image build.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

devcontainer_log_info "Updating apt indexes"
devcontainer_run_as_root apt-get update

devcontainer_log_info "Installing base apt packages"
devcontainer_run_as_root apt-get install -y --no-install-recommends \
	bat \
	ca-certificates \
	coreutils \
	curl \
	entr \
	fd-find \
	file \
	fzf \
	git \
	git-delta \
	git-lfs \
	gnupg \
	hyperfine \
	jq \
	less \
	locales \
	lsof \
	make \
	parallel \
	pkg-config \
	psmisc \
	ripgrep \
	rsync \
	shellcheck \
	shfmt \
	sqlite3 \
	strace \
	sudo \
	tar \
	tree \
	tzdata \
	unzip \
	vim \
	xz-utils \
	yq \
	zip

# The Debian package ships the binary as `fdfind` to avoid a name clash.
# Expose it as `fd` (the canonical name used by sharkdp/fd upstream and
# expected by Pi's tools-manager and most ecosystem configs).
devcontainer_run_as_root ln -sfn /usr/bin/fdfind /usr/local/bin/fd

devcontainer_log_info "Base apt packages installed"
