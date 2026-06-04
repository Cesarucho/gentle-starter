#!/usr/bin/env bash
set -euo pipefail

apt-get update

apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    locales \
    sudo \
    tree \
    tzdata