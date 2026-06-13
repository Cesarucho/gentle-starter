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
    file \
    fzf \
    git \
    git-delta \
    git-lfs \
    hyperfine \
    jq \
    less \
    locales \
    lsof \
    make \
    parallel \
    pkg-config \
    psmisc \
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

devcontainer_log_info "Base apt packages installed"
