#!/usr/bin/env bash
set -euo pipefail

: "${GO_VERSION:=latest}"

arch="$(dpkg --print-architecture)"
case "${arch}" in
amd64)
	go_arch="amd64"
	;;
arm64)
	go_arch="arm64"
	;;
*)
	echo "Unsupported architecture for Go: ${arch}" >&2
	exit 1
	;;
esac

if [ "${GO_VERSION}" = "latest" ]; then
	GO_VERSION="$(curl -fsSL "https://go.dev/dl/?mode=json" | jq -r '.[0].version')"
fi

archive="${GO_VERSION}.linux-${go_arch}.tar.gz"
download_url="https://go.dev/dl/${archive}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

curl -fsSL "${download_url}" -o "${tmp_dir}/${archive}"
rm -rf /usr/local/go
tar -C /usr/local -xzf "${tmp_dir}/${archive}"
ln -sfn /usr/local/go/bin/go /usr/local/bin/go
ln -sfn /usr/local/go/bin/gofmt /usr/local/bin/gofmt

go version
