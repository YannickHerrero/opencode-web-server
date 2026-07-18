# OpenCode Web Server for This Mac

Runs OpenCode as a persistent macOS LaunchAgent rooted at `~/dev` and exposes it securely to this Tailscale tailnet.

## Design

- OpenCode listens only on `127.0.0.1:4096`; it is not exposed on the LAN or public network.
- Tailscale Serve terminates HTTPS and proxies tailnet traffic to that local port.
- `launchd` starts the server after graphical login and restarts it after exit or a crash.
- The Mac must remain awake. Amphetamine manages that policy; this setup deliberately does not duplicate it with `caffeinate`.

## Install

```zsh
./install.zsh
tailscale serve --bg 4096
```

The Tailscale Serve configuration is stored by Tailscale and survives restarts.

## Access

| Client | Address |
| --- | --- |
| Local browser | `http://127.0.0.1:4096` |
| Tailnet browser | `https://macbook.tailf3d9b7.ts.net` |
| Local TUI | `opencode attach http://127.0.0.1:4096` |
| Tailnet TUI | `opencode attach https://macbook.tailf3d9b7.ts.net` |

## Verify

```zsh
curl --fail --silent --show-error http://127.0.0.1:4096/global/health
tailscale serve status
launchctl print gui/$(id -u)/com.yannickherrero.opencode-web
```

## Operations

Restart after changing the plist or upgrading OpenCode:

```zsh
./install.zsh
```

View server logs:

```zsh
tail -f ~/Library/Logs/opencode-web.log
```

Disable the service:

```zsh
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.yannickherrero.opencode-web.plist
```

Remove the Tailscale proxy separately, if wanted:

```zsh
tailscale serve reset
```

## Availability Notes

This is a user LaunchAgent, so it becomes available after your user account signs in. It is unavailable while the Mac sleeps, including when the lid is closed. Tailscale ACLs control which tailnet devices can reach the HTTPS endpoint; no OpenCode basic-auth credentials are stored in this repository.
