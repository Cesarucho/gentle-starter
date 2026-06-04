#!/usr/bin/env bash
set -euo pipefail

apt-get update

apt-get install -y --no-install-recommends \
	ca-certificates \
	coreutils \
	curl \
	git \
	jq \
	locales \
	sudo \
	tar \
	tree \
	tzdata
