# Remote SSH into `core` over Tailscale

Codex App, VS Code Remote SSH, or a plain `ssh` from any device on the tailnet, landing in a shell
**inside `core`** — the same container the dev container uses, with the same workspace bind and the
same toolchain.

    client ---- tailnet tcp/22 ----> tailscaled in core ---- 127.0.0.1:2222 ----> sshd

Opt-in. Nothing loads `compose.remote-access.yaml` implicitly.

This document is one of three. `umaxica-apps-global`, `umaxica-apps-edge` and `portal` share one
contract, described in `plans/global-portal-edge-dreamy-spring.md`; only the account name, the
tailnet hostname and the toolchain differ. **Fix something here, fix it in all three.**

## What runs where

|                      |                                                                                              |
| -------------------- | -------------------------------------------------------------------------------------------- |
| SSH server           | inside `core`, as `global`, on port 2222                                                     |
| sshd config          | `/etc/ssh/remote-sshd_config` (baked, 0444 root)                                             |
| sshd wrapper         | `/usr/local/bin/remote-sshd-entrypoint` (baked, 0555 root)                                   |
| authorized keys      | `.secrets/codex_authorized_keys` → `/home/global/.config/umaxica/authorized_keys`, read-only |
| sshd host key        | volume `umaxicaappsglobaldc_sshd-host-keys` → `/home/global/.local/state/remote-sshd`        |
| Tailscale node state | volume `umaxicaappsglobaldc_tailscale-state` → `/home/global/.local/state/tailscale`         |
| tailnet hostname     | `umaxica-global-core`                                                                        |
| tailnet tag          | `tag:umaxica-devcontainer`                                                                   |

Tailscale runs **inside `core`**, in **userspace networking** mode: no `/dev/net/tun`, no
`CAP_NET_ADMIN`, no `privileged`, no `network_mode: host`, no Podman socket. `core`'s own
`cap_drop: ALL` and `no-new-privileges` hold unchanged — tailscaled runs as `global`, its netstack
terminates tailnet connections, and `tailscale serve` forwards tcp/22 to sshd over loopback. The
pinned client is baked by the Containerfile; the remote-access overlay starts it via
`remote-sshd-entrypoint`, and in a plain dev container the `/usr/local/bin/tailscale` wrapper starts
it on first use, so an interactive `tailscale up` also works. (This used to be a sidecar.)

Tailscale SSH (`tailscale up --ssh`) is deliberately **not** used. It would bypass sshd and the
authorized-keys contract below.

## Before the first start: the tailnet policy

`tailscale serve --tcp=22` is reachable by **the whole tailnet** unless the policy says otherwise.
Set this up first; it is the actual access control, and neither the compose file nor sshd can
substitute for it.

```jsonc
{
  "tagOwners": {
    // Only you may mint keys carrying this tag, and only you may retag a node.
    "tag:umaxica-devcontainer": ["autogroup:admin"],
  },

  "grants": [
    {
      // Your own devices, and nothing else, may open tcp/22 on the three dev
      // containers. Narrow this further with a specific device tag if the
      // tailnet has members who should not reach it.
      "src": ["autogroup:owner"],
      "dst": ["tag:umaxica-devcontainer"],
      "ip": ["tcp:22"],
    },
  ],

  // The dev containers originate nothing; they only answer. Without a rule
  // granting them egress to other tailnet nodes, a compromised container cannot
  // use the tailnet to reach anything else on it.
}
```

## First-time enrolment

1. **Put the client's public key where sshd can read it.**

   ```bash
   install -d -m 0700 .secrets
   install -m 0600 /dev/null .secrets/codex_authorized_keys
   cat ~/.ssh/id_ed25519.pub >> .secrets/codex_authorized_keys
   ```

   The `.pub` half only. `.secrets/` is gitignored.

2. **Mint a one-off auth key** in the Tailscale admin console:

   - **one-off** (single use)
   - **tagged** `tag:umaxica-devcontainer`
   - **pre-approved**, if device approval is on for the tailnet
   - **not ephemeral** — an ephemeral node is deleted when the container stops, which throws away
     the persisted identity this whole design is built on

3. **Put it in `.env` for exactly one start.**

   ```bash
   echo 'TS_AUTHKEY=tskey-auth-...' >> .env
   ```

   Appending is safe; `.devcontainer/write-host-ids.sh` only rewrites `UID`/`GID`. `.env` is
   gitignored — the preflight refuses to run if it ever becomes tracked.

4. **Start it.**

   ```bash
   .devcontainer/remote-access-preflight.sh
   podman compose -f compose.yaml -f compose.remote-access.yaml up -d
   ```

5. **Confirm the node registered.**

   ```bash
   podman exec umaxicaappsglobaldc_core_1 tailscale status
   ```

   `umaxica-global-core` should appear, tagged, and not marked ephemeral.

6. **Revoke the key, then delete the line.**

   ```bash
   sed -i '/^TS_AUTHKEY=/d' .env
   ```

   Revocation in the admin console is the half that matters — deleting the line only stops it being
   handed to the container again. From here on the node starts from
   `umaxicaappsglobaldc_tailscale-state` alone.

   The preflight **refuses to start** while a `TS_AUTHKEY` is still set on an already-enrolled node,
   so this step cannot be quietly skipped.

## Client configuration

```sshconfig
Host umaxica-global-core
  HostName umaxica-global-core.<your-tailnet>.ts.net
  User global
  Port 22
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  ServerAliveInterval 30
```

The container prints its host key fingerprint at every start
(`podman logs umaxicaappsglobaldc_core_1`), so `known_hosts` can be verified rather than accepted
blind. The fingerprint is stable across recreates because the key lives on a volume; it changes only
if that volume is deleted.

Then:

```bash
ssh umaxica-global-core
hostname; pwd; git status --short; ruby --version; bundle --version; node --version; pnpm --version
```

`hostname` reports the `core` container, and `pwd` is `/home/global/workspace` — the workspace bind,
not a copy.

## Restart behaviour

```bash
podman compose -f compose.yaml -f compose.remote-access.yaml down
podman compose -f compose.yaml -f compose.remote-access.yaml up -d
ssh umaxica-global-core hostname
```

No auth key, same tailnet node, same SSH host key. `down -v` is the exception: it destroys both
volumes, which deregisters the node and forces a fresh enrolment.

## Known constraints

- **The tcp/22 forward is the documented CLI form.**
  `tailscale serve --bg --tcp=22 tcp://127.0.0.1:2222`, run by `remote-sshd-entrypoint` on every
  start — a same-config re-run is a no-op, so the script stays the source of truth. The former
  sidecar relied on an undocumented `TCPForward` to a sibling container name; forwarding over
  loopback inside `core` is the supported shape.

- **Rootless restart policies need the user unit.** `restart: on-failure:3` does nothing across a
  host reboot without `systemctl --user enable --now podman-restart.service`.

- **`podman-compose` needs `default` declared.** Any overlay that gives a service an explicit
  `networks:` list must also declare `default` at the top level, or podman-compose 1.6.0 fails with
  `missing networks: default`.

- **An SSH session builds its environment from scratch.** sshd inherits nothing from the container's
  main process, so two mechanisms put it back:

  1. The single `SetEnv` line in `remote-sshd_config` carries the toolchain paths. It must stay ONE
     line -- sshd_config keeps the first value it sees for a keyword and silently discards the rest,
     so a second `SetEnv` line parses cleanly and does nothing.
  2. `remote-sshd-entrypoint` snapshots the container's own environment to
     `/run/sshd/session-env.sh` at startup and prepends a source line to `~/.bashrc`. That is what
     carries the variables Compose sets on the service, which `SetEnv` cannot -- it is a static list
     and they change with `compose.yaml`.

  The line is PREPENDED, not appended: Debian's stock `~/.bashrc` opens with a
  `case ehuB in *i*) ;; *) return;; esac` guard, so anything after it is unreachable for
  `ssh host cmd` -- the shape every Remote-SSH agent uses to run commands. Bash also ignores
  `BASH_ENV` when sshd started it, reading `~/.bashrc` instead, which is why the `.bashrc` route is
  the load-bearing one.

  If a command works under `podman exec` and fails over SSH, this is the first place to look:
  `ssh <host> 'cat /run/sshd/session-env.sh'`.

- **The sshd is unprivileged.** `core` runs `cap_drop: ALL` with `no-new-privileges` under
  `userns_mode: keep-id`, so sshd cannot bind port 22, cannot use PAM, and cannot
  privilege-separate. Port 2222 and `AllowUsers global` follow from that.

- **`bun` is not installed and is not planned.** This image is Ruby plus Node and pnpm. A completion
  checklist that expects `bun --version` is checking for something no repository in this group
  ships.

- **The compose project name is `umaxicaappsglobaldc`,** set in `.devcontainer/compose.yaml`. It
  carries no separators because the Dev Containers CLI derives its own project name from
  `devcontainer.json`'s `name` by stripping every non-alphanumeric character and passes it as
  `--project-name`; a separated value in the Compose files would put a bare `podman compose` in a
  second project that collides with the Dev Container over the `global-devcontainer-*` container
  names and the published ports. Volume names are prefixed with the project name, which is why the
  preflight looks for `umaxicaappsglobaldc_tailscale-state`. A bare
  `podman compose -f compose.yaml -f compose.remote-access.yaml` without the override uses a
  different project and therefore different, empty volumes — include the override, or expect to
  enrol a second node.
