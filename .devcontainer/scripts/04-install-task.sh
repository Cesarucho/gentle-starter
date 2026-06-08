#!/usr/bin/env bash
set -euo pipefail

curl -1sLf "https://dl.cloudsmith.io/public/task/task/setup.deb.sh" | bash -

apt-get install -y --no-install-recommends task

task --version
