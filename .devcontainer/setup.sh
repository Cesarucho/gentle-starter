#!/usr/bin/env bash
set -euo pipefail

# sudo chown -R ${UID}:${UID} ${HOME}/.codex

# Fix project file permissions to standard privileges
sudo chown -R ${UID}:${UID} ${PWD}
sudo find ${PWD} -type d -exec chmod 755 {} +
sudo find ${PWD} -type f ! -name "*.sh" -exec chmod 644 {} +
sudo find ${PWD} -type f -name "*.sh" -exec chmod 755 {} +

# Setup git files configurations
sudo chown -R ${UID}:${UID} ${HOME}/.gitconfig-volume

touch ${HOME}/.gitconfig-volume/config
ln -fs ${HOME}/.gitconfig-volume/config ${HOME}/.gitconfig
sudo chown -R ${UID}:${UID} ${HOME}/.gitconfig

touch ${HOME}/.gitconfig-volume/.git-credentials
ln -fs ${HOME}/.gitconfig-volume/.git-credentials ${HOME}/.git-credentials
sudo chown -R ${UID}:${UID} ${HOME}/.git-credentials

if ! git config --global --get-all safe.directory | grep -Fxq "${PWD}"; then
  git config --global --add safe.directory ${PWD}
fi

git config --global alias.logline \
  "log --graph --decorate --abbrev-commit --date=short --pretty=format:'%C(yellow)%h%Creset %C(cyan)%ad%Creset %Cgreen%s%Creset %Cblue(%an)%Creset %C(red)%d%Creset'"

git config --global alias.config-list "config --list --show-origin --show-scope"

# Install pi agents and tools
# pi install npm:gentle-pi
# pi install npm:pi-subagents
# pi install npm:pi-intercom
# pi install npm:gentle-engram
# pi install npm:pi-web-access
# pi install npm:pi-lens
# pi install npm:@juicesharp/rpiv-todo
# pi install npm:@juicesharp/rpiv-ask-user-question
pi update
