#!/bin/zsh
set -euo pipefail

label="com.yannickherrero.opencode-web"
menu_label="com.yannickherrero.opencode-web-menu"
user_domain="gui/$(id -u)"
repository_directory="${0:A:h}"
source_plist="${repository_directory}/launchd/${label}.plist"
menu_source_plist="${repository_directory}/launchd/${menu_label}.plist"
destination_plist="${HOME}/Library/LaunchAgents/${label}.plist"
menu_destination_plist="${HOME}/Library/LaunchAgents/${menu_label}.plist"
menu_application="${HOME}/Applications/OpenCode Status.app"
menu_install_directory="${menu_application}/Contents/MacOS"
menu_binary="${menu_install_directory}/OpenCodeStatus"
menu_info_plist="${menu_application}/Contents/Info.plist"

if [[ ! -x "${HOME}/.opencode/bin/opencode" ]]; then
  print -u2 "OpenCode was not found at ${HOME}/.opencode/bin/opencode"
  exit 1
fi

if [[ ! -d "${HOME}/dev" ]]; then
  print -u2 "Working directory ${HOME}/dev does not exist"
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  print -u2 "Swift is required to build the menu-bar utility"
  exit 1
fi

(
  cd "${repository_directory}"
  swift build -c release
)

mkdir -p "${HOME}/Library/Logs"
mkdir -p "${menu_install_directory}"
cp "${repository_directory}/.build/release/opencode-web-menu" "${menu_binary}"
cp "${repository_directory}/app/Info.plist" "${menu_info_plist}"

configure_bartender_visibility() {
  local preferences="${HOME}/Library/Preferences/com.surteesstudios.Bartender.plist"
  local menu_item="com.yannickherrero.opencode-web-menu-Item-0"
  local visible_items

  [[ -f "${preferences}" ]] || return
  visible_items="$(/usr/libexec/PlistBuddy -c 'Print :ProfileSettings:activeProfile:Show' "${preferences}" 2>/dev/null)"
  if [[ "${visible_items}" != *"${menu_item}"* ]]; then
    /usr/libexec/PlistBuddy -c "Add :ProfileSettings:activeProfile:Show: string ${menu_item}" "${preferences}"
  fi
}

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
install_agent "${menu_label}" "${menu_source_plist}" "${menu_destination_plist}"
configure_bartender_visibility

print "Installed and started ${label} and ${menu_label}."
