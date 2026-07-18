#!/bin/zsh
set -euo pipefail

label="com.yannickherrero.opencode-web"
user_domain="gui/$(id -u)"
repository_directory="${0:A:h}"
source_plist="${repository_directory}/launchd/${label}.plist"
destination_plist="${HOME}/Library/LaunchAgents/${label}.plist"
legacy_menu_label="com.yannickherrero.opencode-web-menu"
legacy_menu_plist="${HOME}/Library/LaunchAgents/${legacy_menu_label}.plist"

if [[ ! -x "${HOME}/.opencode/bin/opencode" ]]; then
  print -u2 "OpenCode was not found at ${HOME}/.opencode/bin/opencode"
  exit 1
fi

if [[ ! -d "${HOME}/dev" ]]; then
  print -u2 "Working directory ${HOME}/dev does not exist"
  exit 1
fi

mkdir -p "${HOME}/Library/Logs"

install_agent() {
  local agent_label="$1"
  local source="$2"
  local destination="$3"

  if launchctl print "${user_domain}/${agent_label}" >/dev/null 2>&1; then
    launchctl bootout "${user_domain}/${agent_label}"
    sleep 1
  fi

  cp "${source}" "${destination}"
  launchctl bootstrap "${user_domain}" "${destination}"
  launchctl kickstart -k "${user_domain}/${agent_label}"
}

install_agent "${label}" "${source_plist}" "${destination_plist}"

if launchctl print "${user_domain}/${legacy_menu_label}" >/dev/null 2>&1; then
  launchctl bootout "${user_domain}/${legacy_menu_label}"
fi
rm -f "${legacy_menu_plist}"

print "Installed and started ${label}."
