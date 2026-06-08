#!/usr/bin/env bash
set -euo pipefail

: "${TZ:=America/Mexico_City}"
: "${LOCALE:=es_MX.UTF-8}"

ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
echo "${TZ}" >/etc/timezone
dpkg-reconfigure -f noninteractive tzdata

if grep -q "^# ${LOCALE} UTF-8" /etc/locale.gen; then
	sed -i "s/^# ${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
elif ! grep -q "^${LOCALE} UTF-8" /etc/locale.gen; then
	echo "${LOCALE} UTF-8" >>/etc/locale.gen
fi

locale-gen "${LOCALE}"
update-locale LANG="${LOCALE}" LANGUAGE="${LOCALE}" LC_ALL="${LOCALE}"
