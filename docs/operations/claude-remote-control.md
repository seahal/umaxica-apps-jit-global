# Claude Code Remote Control (WS3B)

Claude Code Remote Control connects [claude.ai/code](https://claude.ai/code) or the Claude mobile
app to a `claude` process running inside `core`. Execution and filesystem access stay entirely on
the host machine; only outbound HTTPS traffic to `api.anthropic.com` is required. Remote Control
needs no inbound SSH and no inbound ports at all.

|           | Claude Remote Control                   |
| --------- | --------------------------------------- |
| Transport | Outbound HTTPS only, no inbound ports   |
| Client    | claude.ai/code, Claude mobile app       |
| Auth      | `claude.ai` OAuth session inside `core` |

It depends only on: host reboot recovery, rootless Podman availability, `core` container lifecycle,
persistent development volumes, and logging conventions.

## Requirements (from Anthropic's official documentation)

- **Authentication is OAuth-only.** Run `claude` inside `core` and use `/login` (or
  `claude auth login`) to sign in with a claude.ai account. API-key-only authentication is not
  supported for Remote Control.
- If `ANTHROPIC_API_KEY` is set in the container environment, unset it — an API key present
  alongside an OAuth session can cause Remote Control to report it is disabled.
- `ANTHROPIC_BASE_URL` must be unset or point at `api.anthropic.com`. Remote Control is disabled
  when it points elsewhere (LLM gateway, proxy).
- Outbound TCP 443 to `api.anthropic.com` must be reachable from `core`.
- Not available when Claude Code is running against Amazon Bedrock, Google Cloud's Agent Platform,
  or Microsoft Foundry.
- **Network-outage behavior**: if `core` loses network reachability for roughly 10 minutes while a
  Remote Control session is active, the process times out and exits. This is why the systemd unit
  below uses `Restart=always` rather than `Restart=on-failure` — a clean timeout exit must still
  trigger a restart.
- **The local process must keep running.** If the `claude remote-control` process exits and is not
  restarted, the session ends. This is the entire reason for the systemd unit in this gate.

OAuth credential state persists across container recreation because `~/.claude` is a writable
persistent named volume (see `.devcontainer/devcontainer.json`). The host's Claude state directory
is not mounted into `core`. The auxiliary `~/.claude.json` file is container-local and may be
regenerated after recreation; it is not the persistent OAuth credential store.

## Architecture

```text
Host: systemd --user unit (claude-remote-control.service)
    |  ExecStart -> podman/remote-control/bin/start-remote-control.sh
    |     1. devcontainer up   (idempotent; brings up the Dev Container stack)
    |     2. wait for `devcontainer exec ... true` to succeed
    |     3. exec devcontainer exec ... claude remote-control --spawn=same-dir
    v
core container (rootless Podman)
    |  outbound HTTPS 443 only
    v
Anthropic API (api.anthropic.com) <-> claude.ai/code, Claude mobile app
```

## Repository Artifacts

| Path                                                           | Purpose                                                             |
| -------------------------------------------------------------- | ------------------------------------------------------------------- |
| `podman/remote-control/claude-remote-control.service.template` | User-level systemd unit template. Not installed automatically.      |
| `podman/remote-control/bin/start-remote-control.sh`            | Brings up the stack, waits for `core` health, execs Remote Control. |

## Install (manual host gate — you run these, not the agent)

These steps require host privileges and are never performed automatically from inside the container,
per the repository's operating constraints.

1. Copy the template out of the repository into your user systemd directory and fill in the two
   `CHANGEME_` placeholders (absolute path to this repository clone on the host, and optionally a
   `PATH` override if `devcontainer` is not on the default systemd user `PATH`):

   ```sh
   mkdir -p ~/.config/systemd/user
   cp podman/remote-control/claude-remote-control.service.template \
     ~/.config/systemd/user/claude-remote-control.service
   $EDITOR ~/.config/systemd/user/claude-remote-control.service
   ```

2. Reload the user systemd manager and enable the unit:

   ```sh
   systemctl --user daemon-reload
   systemctl --user enable --now claude-remote-control.service
   ```

3. If reboot recovery is not already configured for this project (see
   `plans/umaxica-rails-expressive-dewdrop.md`), also enable lingering and `podman-restart.service`
   so the container stack itself survives a reboot before this unit tries to use it:

   ```sh
   loginctl enable-linger "$(whoami)"
   systemctl --user enable --now podman-restart.service
   ```

4. Confirm the OAuth session inside `core` is authenticated before relying on the unit to start a
   session unattended:
   ```sh
   devcontainer exec --workspace-folder "$(pwd)" claude /status
   ```

## Verify

```sh
systemctl --user status claude-remote-control.service
journalctl --user -u claude-remote-control.service -f
```

A healthy unit shows the `bringing up the Dev Container stack`, `waiting for core`, and
`starting claude remote-control` log lines from `start-remote-control.sh`, followed by Remote
Control's own session-URL output in the journal.

## Reboot and Recovery Test Matrix

Run each row after a real host reboot; record pass/fail and the exact recovery command used for any
failure. This matrix is intentionally more granular than a single "does it come back" check, per the
repository's engagement rules.

| #   | Scenario                                           | Expected                                                                                                   | Recovery command if failed                                                                                       |
| --- | -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| 1   | Host reboot, user not logged in, lingering enabled | Unit starts anyway (lingering)                                                                             | `loginctl enable-linger "$(whoami)"`, then `systemctl --user start claude-remote-control.service`                |
| 2   | Host reboot, user logs in shortly after            | Unit already running by the time of login                                                                  | `systemctl --user status claude-remote-control.service`                                                          |
| 3   | Podman service availability after reboot           | `podman-restart.service` brought container stack up before this unit needed it                             | `systemctl --user restart podman-restart.service`, then `systemctl --user restart claude-remote-control.service` |
| 4   | Container recreation (e.g. image rebuilt)          | `devcontainer up` in the script recreates it transparently                                                 | `devcontainer up --workspace-folder <repo>` manually, then restart the unit                                      |
| 5   | Remote Control process restart after crash         | `Restart=always` brings it back within `RestartSec=10`                                                     | `systemctl --user restart claude-remote-control.service`                                                         |
| 6   | Mac reconnection (claude.ai/code or mobile app)    | Session reappears in the session list once the unit is healthy again                                       | none — client-side reconnect is automatic per Anthropic's docs                                                   |
| 7   | Credential expiration / OAuth session invalidated  | Unit logs an authentication failure in the journal; does not silently loop forever without a visible error | `devcontainer exec --workspace-folder <repo> claude auth login`                                                  |
| 8   | Failure logging                                    | `journalctl --user -u claude-remote-control.service` shows a clear reason for every restart                | n/a — this is the check itself                                                                                   |

## Troubleshooting

- **`devcontainer: command not found`**: systemd `--user` services often start with a minimal
  `PATH`. Uncomment and set the `Environment=PATH=...` line in the unit file to include the
  directory containing the `devcontainer` CLI.
- **Unit restarts every ~10 minutes with no other symptoms**: expected under a real network outage —
  this is the documented Remote Control timeout behavior, not a bug in this unit.
- **"Remote Control requires a claude.ai subscription" in the journal**: the OAuth session inside
  `core` is missing or was created with `claude setup-token` / `CLAUDE_CODE_OAUTH_TOKEN` (model-only
  scope). Run `claude auth login` inside `core` interactively once.

## Non-Goals

- This gate does not modify `/etc`, enable lingering, or install the unit — all of that remains a
  manual host action per the repository's engagement rules.
- This gate does not change the reboot-autostart gap, which remains open and undocumented-as-fixed
  unless separately scoped.
- No secrets are stored in the unit file or helper script; authentication relies entirely on the
  OAuth session persisted in the `~/.claude` named volume.
