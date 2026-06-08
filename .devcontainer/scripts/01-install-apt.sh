#!/usr/bin/env bash
set -euo pipefail

apt-get update

apt-get install -y --no-install-recommends \
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
