#!/usr/bin/env bash
set -euo pipefail

: "${HOST_UID:=1001}"
: "${HOST_GID:=1001}"

if [ "${HOST_UID}" != "1000" ]; then
	groupadd -g "${HOST_GID}" devuser 2>/dev/null || true

	if ! id -u devuser >/dev/null 2>&1; then
		useradd -u "${HOST_UID}" -g "${HOST_GID}" -m -s /bin/bash devuser 2>/dev/null || true
	fi

	echo "devuser ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/90-devuser
	chmod 0440 /etc/sudoers.d/90-devuser
fi

# if id -u ubuntu >/dev/null 2>&1; then
#     useradd -m -s /bin/bash ubuntu
# fi

echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/95-ubuntu
chmod 0440 /etc/sudoers.d/95-ubuntu

# mkdir -p /home/ubuntu/code
# chown -R ubuntu:ubuntu /home/ubuntu
