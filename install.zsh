#!/bin/zsh
set -euo pipefail

label="com.yannickherrero.opencode-web"
user_domain="gui/$(id -u)"
source_plist="${0:A:h}/launchd/${label}.plist"
destination_plist="${HOME}/Library/LaunchAgents/${label}.plist"

if [[ ! -x "${HOME}/.opencode/bin/opencode" ]]; then
  print -u2 "OpenCode was not found at ${HOME}/.opencode/bin/opencode"
  exit 1
fi

if [[ ! -d "${HOME}/dev" ]]; then
  print -u2 "Working directory ${HOME}/dev does not exist"
  exit 1
fi

mkdir -p "${HOME}/Library/Logs"

if launchctl print "${user_domain}/${label}" >/dev/null 2>&1; then
  launchctl bootout "${user_domain}/${label}"
fi

cp "${source_plist}" "${destination_plist}"
launchctl bootstrap "${user_domain}" "${destination_plist}"
launchctl kickstart -k "${user_domain}/${label}"

print "Installed and started ${label}."
