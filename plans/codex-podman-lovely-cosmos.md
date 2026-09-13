# Codex App SSH into `core` over a Tailscale Sidecar

## Context

The Codex App needs a real shell inside the `core` development container — its filesystem, its
Ruby/Rails toolchain, its pnpm — reached from a Mac over the tailnet. Today there is no inbound path
into `core` at all: the Cloudflare connector is outbound-only, Claude Remote Control is
outbound-only, and host publications are loopback-only.

This repository has tried remote access twice already, and both attempts are informative:

1. **`c41e66ed0` (2026-07-22)** built exactly the architecture requested here — a `tailscale-codex`
   sidecar in userspace mode, TCP-forwarding tailnet 22 to an OpenSSH server inside `core`, on a
   dedicated `remote-access` network with a persistent state volume. It worked. It was then replaced
   by direct-in-`core` Tailscale SSH.
2. That replacement is **currently being ripped out in the working tree** (staged deletions of
   `.devcontainer/tailscale-core-*.sh` and `docs/operations/remote-codex-over-tailscale.md`). Its
   recorded failure reason is decisive: `tailscale-core-supervisor` needed a real **root PID 1**,
   which conflicts with `userns_mode: keep-id` and the deliberate absence of a `user:` key in
   `compose.yaml`.

So this plan restores approach (1), which is the shape the container's ownership model can actually
support, and adapts it to two things that changed since: `core` now has **no `sudo` and no root**
(the sudo-less workspace work), and a contract test now bans Tailscale from `devcontainer.json` and
the `Containerfile`.

Confirmed decisions: drop `bun` from the acceptance criteria (it is not installed anywhere and
adding it is out of scope); use **tailnet port 22**; take the Codex public key from a **gitignored
repo file**.

## The Shape

```text
Codex App  ──SSH over tailnet TCP/22──▶  tailscale sidecar  (userspace, no caps)
                                              │  TS_SERVE_CONFIG TCPForward
                                              ▼
                                         core:2222  ── sshd, running as `global`
                                              ├─ /home/global/workspace (the repo)
                                              └─ ruby / bundle / pnpm
```

`2222` inside the container is not a compromise on the "expose only TCP/22" requirement: the
tailnet-facing port is 22, and 2222 is never published to the host or to any other network. It is
required because **sshd in `core` runs as the unprivileged `global` user** and cannot bind a
privileged port. There is no root available to do otherwise, and reintroducing one is what sank the
previous attempt.

## Changes

### 1. `Containerfile` — add `openssh-server` to the `development` stage

One package added to the existing `apt-get install` list next to `openssh-client` (~line 311). The
`production` stage is untouched and keeps no sshd. Nothing here mentions Tailscale, so the
`"the development container carries no Tailscale"` contract test still passes unmodified.

### 2. `podman/core/sshd_config` (new) + `docker/core/sshd_config` (new, identical copy)

Recover the prior config from `git show c41e66ed0^:docker/core/sshd_config` and adapt it for
non-root operation. It already specifies the required posture (`PermitRootLogin no`,
`PubkeyAuthentication yes`, `AuthenticationMethods publickey`, `PasswordAuthentication no`,
`UsePAM no`, `StrictModes yes`, and the surface reductions `AllowTcpForwarding no`,
`AllowAgentForwarding no`, `X11Forwarding no`, `PermitTunnel no`, `GatewayPorts no`,
`PermitUserEnvironment no`). Changes from that version:

- `Port 2222` (was 22)
- `HostKey /home/global/.local/state/umaxica-sshd/ssh_host_ed25519_key` — a path `global` owns
- `PidFile /home/global/workspace/tmp/pids/sshd.pid` — `TMPDIR` is already normalized there
- `AuthorizedKeysFile /home/global/.config/umaxica/authorized_keys` (read-only bind, below)

The `docker/` and `podman/` trees are byte-identical copies today; keep that invariant even though
only `podman/` is built from.

### 3. `podman/core/entrypoint.sh` + `docker/core/entrypoint.sh` — opt-in sshd block

Reintroduce a `REMOTE_SSHD=1`-gated block, modeled on
`git show c41e66ed0^:docker/core/entrypoint.sh` but with **every `sudo` removed** — all paths are
`global`-owned now. It must run on the `EUID == WORKLOAD_UID` fast path (the keep-id path), before
the final `exec "$@"`, and must:

- fail loudly and exit non-zero if `/usr/sbin/sshd` is missing, if the config is unreadable, or if
  the authorized_keys file is missing/empty (per `generic/no-silent-fallback.mdc` — no silent
  degradation to "no remote access")
- reject a group- or other-writable authorized_keys file (`StrictModes` would too, but failing at
  startup names the problem)
- `ssh-keygen -t ed25519 -N "" -f "${HOST_KEY}"` once if absent, `chmod 0600`
- be re-entrant: check the PidFile and skip if an `sshd` is already alive
- `sshd -t -f "${SSHD_CONFIG}"` before starting, then start detached

The host key lives on a named volume so the Mac's `known_hosts` entry survives recreation.

### 4. `compose.custom.yaml` — the sidecar, network, and volumes

The overlay is the correct home: it is the developer-owned file, it is always merged, and adding the
sidecar there keeps `devcontainer.json` and `Containerfile` free of the word "tailscale". Recover
the service from `git show c41e66ed0^:.devcontainer/compose.override.yml` and update it:

```yaml
tailscale-core:
  image: docker.io/tailscale/tailscale:v1.102.3 # pin; match the host daemon
  profiles: [remote]
  environment:
    TS_USERSPACE: "true" # default, but explicit: this is the security boundary
    TS_AUTH_ONCE: "true" # image default is false -> would re-`up` every boot
    TS_STATE_DIR: /var/lib/tailscale
    TS_HOSTNAME: umaxica-global-core
    TS_ACCEPT_DNS: "false" # must stay off, see Constraints
    TS_ENABLE_HEALTH_CHECK: "true"
    TS_EXTRA_ARGS: "--advertise-tags=tag:umaxica-core"
    TS_SERVE_CONFIG: /etc/tailscale/serve/serve.json
    TS_AUTHKEY: "${TS_AUTHKEY:-}" # bootstrap only; blanked afterwards
  volumes:
    - type: volume
      source: tailscale-core-state
      target: /var/lib/tailscale
    - "./podman/tailscale/serve:/etc/tailscale/serve:ro,z" # directory, not file
  networks: [remote-access]
  restart: on-failure:3
  cpus: 0.5
  mem_limit: 256m
  pids_limit: 128
  logging: { driver: json-file, options: { max-size: "10m", max-file: "3" } }
```

Constraints this satisfies, each deliberate:

- **No `privileged`, no `network_mode: host`, no `/dev/net/tun`, no `cap_add`, no engine socket, and
  no `ports:`.** Userspace netstack terminates the tailnet TCP connection inside tailscaled and
  dials `core` as an ordinary socket, so none of them are needed. Tailscale's own Docker example
  pairs `NET_ADMIN`/`NET_RAW` with userspace mode — that is over-provisioned; do not copy it.
- `restart: on-failure:3`, matching `cloudflare-tunnel`. `unless-stopped` is banned by the
  `"no service restarts without a bound"` contract test.
- Resource caps mirror the connector so a crash loop is bounded.
- `profiles: [remote]` keeps a plain `podman compose up` from ever starting or pulling it; enable
  with `COMPOSE_PROFILES=remote` in `.env`.

Also in this file: `core` gains `REMOTE_SSHD: "1"`, the `remote-access` network, and the read-only
authorized_keys bind. **`core`'s `networks:` key must be written out in full** — a service-level
`networks:` list in an overlay _replaces_ the base list rather than merging, and `core`'s base entry
carries ~50 `frontend` aliases that every Cloudflare ingress rule depends on. Use the mapping form
and add `remote-access: {}` alongside the existing four; the existing contract test for the
connector documents exactly this hazard.

New top-level entries: network `remote-access: {}` (a plain bridge — it is the sidecar's only
network, so its control-plane/DERP egress rides it too; `internal: true` would force the sidecar
onto a shared network and _widen_ exposure), and volumes `tailscale-core-state: {}` and
`umaxica-sshd-hostkey: {}`.

### 5. `podman/tailscale/serve/serve.json` (new) + `docker/tailscale/serve/serve.json`

```json
{
  "TCP": {
    "22": {
      "TCPForward": "core:2222"
    }
  }
}
```

No `TerminateTLS` — SSH clients cannot speak TLS-terminated TCP. The mount is of the containing
**directory**, per the Tailscale docs, so config updates are detected across inode replacement.

### 6. `.secrets/codex_authorized_keys` (operator-created, gitignored)

`.secrets/` is already gitignored and already excluded from both `.containerignore` and
`.dockerignore`, and the contract test asserts all three. Bind it read-only into `core` at
`/home/global/.config/umaxica/authorized_keys`. The operator writes their Codex App public key into
it; a public key is not a credential, so this does not breach the devcontainer charter.

### 7. Tests — `test/unit/security/development_container_contract_test.rb`

The existing `"the development container carries no Tailscale"` test stays as-is and keeps passing.
Add tests asserting the new boundary rather than weakening the old one:

- the sidecar declares `TS_USERSPACE: "true"` and none of `privileged`, `cap_add`, `devices`,
  `network_mode`, or `ports`
- its `networks` is exactly `["remote-access"]`, so it never touches `frontend`/`backend`
- it declares `cpus`, `mem_limit`, `pids_limit`, `logging`, and a bounded `restart`
- it is `profiles`-gated (unlike `cloudflare-tunnel`, which must not be)
- `core`'s overlay `networks` still contains all four base networks plus `remote-access`
- `serve.json` forwards only TCP and only to `core:2222`
- the sshd config sets `PasswordAuthentication no`, `PermitRootLogin no`, and
  `AuthenticationMethods publickey`

### 8. Docs — `docs/operations/remote-codex-over-tailscale.md`

Rewrite rather than restore: the deleted file documents Tailscale SSH, which this design explicitly
does not use. Cover the diagram, the bootstrap sequence, the auth-key revocation step, the
`~/.ssh/config` stanza, and the restart-survival check. English, per
`docs/reference/repository-language-policy.md`.

## Bootstrap

```sh
# 1. Codex App public key
mkdir -p .secrets && cat > .secrets/codex_authorized_keys   # paste the public key

# 2. One-off, tagged, pre-approved, NON-ephemeral auth key from the admin console.
#    Not ephemeral: an ephemeral node is deleted when it goes offline, which would
#    destroy the identity this design exists to preserve.
printf 'TS_AUTHKEY=tskey-auth-...\nCOMPOSE_PROFILES=remote\n' >> .env

# 3. Bring it up
podman compose -f compose.yaml -f compose.custom.yaml up -d core tailscale-core

# 4. Confirm registration, then REVOKE the key in the admin console and blank the
#    .env line. TS_AUTH_ONCE=true means state alone is sufficient from now on.
podman exec global-devcontainer-tailscale tailscale status
```

`~/.ssh/config` on the Mac:

```sshconfig
Host core-dev
  HostName umaxica-global-core   # or umaxica-global-core.<tailnet>.ts.net
  User global
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
```

Tailnet ACL must grant the Mac `tag:umaxica-core:22`. Grants are additive — check existing broad
rules too, and ensure no rule admits `root`.

## Verification

Ordered narrowest-first.

1. **Static**, runnable on the host now: `bash -n podman/core/entrypoint.sh`,
   `python3 -c 'import json;json.load(open("podman/tailscale/serve/serve.json"))'`,
   `podman compose -f compose.yaml -f compose.custom.yaml config >/dev/null`, and
   `diff podman/core/entrypoint.sh docker/core/entrypoint.sh` (must be identical).
2. **Contract tests**: `bin/rails test test/unit/security/development_container_contract_test.rb`
   and `test/tooling/compose_host_port_exposure_test.rb`. Note these must run **inside `core`** —
   `bin/rails` fails on the host, which currently has no installed bundle.
3. **The load-bearing empirical check — non-root sshd.** This is the one genuinely uncertain piece:
   OpenSSH normally runs as root, and running it as `global` is supported only because the
   authenticating user _is_ the running user. Verify directly before anything else:
   ```sh
   podman exec global-devcontainer-core /usr/sbin/sshd -t -f /etc/umaxica/sshd_config
   podman exec global-devcontainer-core ss -ltnp | grep 2222
   podman exec global-devcontainer-core ssh -p 2222 -o StrictHostKeyChecking=no global@127.0.0.1 hostname
   ```
   If sshd refuses to run unprivileged, stop and report — do not paper over it by reintroducing a
   root PID 1, which is precisely the failure this design avoids.
4. **Sidecar reaches core**: `podman exec <sidecar> getent hosts core` (podman container DNS by
   service name is not something Tailscale documents; verify, don't assume) and
   `tailscale serve status`.
5. **End to end**, from another tailnet machine: `ssh core-dev`, then `hostname`, `pwd`,
   `git status`, `ruby --version`, `bundle --version`, `pnpm --version`. Confirm the session is
   really inside `core` with `cat /proc/1/cmdline` (expect `sleep infinity`) and
   `readlink /proc/self/root`.
6. **Restart survival**: `podman compose down` then `up -d` with `TS_AUTHKEY` blank; confirm the
   node returns under the same name and `ssh core-dev` succeeds without re-authenticating.

## Residual Risks

- **A persisted tailnet node identity is a long-lived machine credential**, and the deleted doc
  records the repository's prior stance that it "no longer keeps any". This plan reverses that
  deliberately, because requirement 4 asks for it. The mitigation is the tag + ACL scope, not the
  absence of the credential.
- `global` can read its own sshd host key and Tailscale state is in a separate container, but the
  host account owning rootless Podman can always enter `core` as UID 0. Unchanged from today.
- Inbound network reachability into the dev container is new. It is bounded to tailnet TCP/22 → one
  unprivileged sshd, publickey-only, single user, with forwarding disabled.
