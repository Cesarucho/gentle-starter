#!/usr/bin/env bash
set -euo pipefail

SKILLS_VERSION="${SKILLS_VERSION:-1.5.10}"

npm install -g "skills@${SKILLS_VERSION}"
