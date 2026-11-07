# Docker Sandboxes as the development environment

Status: Proposed on 2026-11-05 at the owner's request. Not triaged. No environment or document
change is authorized by this note.

## Motivation

The Dev Container setup has become costly to operate, and VS Code is not required by anything except
`devcontainer.json` customizations, so the owner no longer wants to depend on it. The owner also
wants a safer setup against supply-chain attacks (malicious gems or npm packages, compromised agent
tooling). Docker Sandboxes is the owner's preferred migration candidate, subject to the constraints
below; the decision spans two axes, the container engine (Podman or Docker) and where code runs
(host, Dev Container or sandbox).

Podman was adopted earlier (`adr/container-support-directory-podman-only.md`,
`research/docker-to-podman-directory-migration.md`), but it has also caused recurring friction; for
example, Codex's bubblewrap sandbox did not work inside the rootless Podman setup. The owner hopes
Docker Sandboxes (`sbx`) reduces this operating burden. Related hardening already applied on
2026-11-05: a 3-day release cooldown in `Gemfile`, `bunfig.toml` (`minimumReleaseAge`) and
`.github/dependabot.yml`.

## Required capabilities (owner)

Docker Sandboxes has not been tried in a proof of concept yet. Any candidate environment must keep
the following, because moving work between the inside and outside of the environment is costly:

1. **Chromium in the same environment.** A Chromium browser runs where the application and the agent
   run (today, `core`), so behavior is verified there without crossing the boundary.
2. **Custom host names.** The environment resolves the project's own names to the application, as
   the `frontend` network aliases on `core` do today (`*.localhost` surfaces and the tunnel's
   Umaxica names).
3. **Remote desktop.** The environment's desktop is viewable from outside through VNC or similar, as
   the noVNC browser desktop does today (`docs/operations/development-browser-desktop.md`).

## Connectivity between the host and the environment

The owner does not want Tailscale inside the environment: it adds an attack surface, and a
compromised environment would become a node on the tailnet. The intended design, to be confirmed in
the proof of concept:

- Files: mount the repository only, never the home directory.
- Shell: the sandbox's own shell or attach command; no SSH server inside.
- Screen: Xvfb, Chromium, x11vnc and noVNC inside the sandbox, as in `core` today. Publish only the
  noVNC port with `sbx ports`, bound to host loopback. Keep RFB (5900) and the Chromium remote
  debugging port unpublished; set a VNC password and use view-only mode when input is not needed.
- Other devices: if needed, use SSH port forwarding to the host (`ssh -L`), not a network agent
  inside the environment.
- Agent verification: prefer headless browser screenshots and traces inside the sandbox; noVNC is
  for human inspection.

Proof-of-concept checks: whether `sbx ports` can bind to loopback only, and whether Xvfb, Chromium
and noVNC run inside the microVM image.

If this works, remove the Tailscale remote-access path (`.devcontainer/tailscale-wrapper.sh`,
`remote-sshd-*`, the profile-gated `remote-access` overlay and
`docs/operations/remote-codex-over-tailscale.md`). The owner considers the current Tailscale and SSH
exposure risky. Removal is a separate, approved change.

## Current environment (static reading)

- Engine: rootless Podman 5 with `podman-compose`, not Docker
  (`docs/operations/development-environment-setup.md`, `container-engine-podman-notes.md`).
- Infrastructure: `compose.yaml` runs PostgreSQL `primary`/`replica`, Valkey, fakecloud, the
  observability stack and the Cloudflare tunnels. Host publication is loopback-only
  (`docs/operations/development-host-port-exposure.md`).
- Application: `.devcontainer/compose.yaml` adds `core` (Rails, Vite, jobs, a noVNC browser
  desktop), built from `Containerfile` target `development` or `workspace` (nested rootless Podman).
  `core` holds many host aliases on the `frontend` network that the tunnel ingress needs.
- Entry point: VS Code Dev Containers (`.devcontainer/devcontainer.json`), which also installs the
  Claude Code and Codex features; `docs/operations/claude-remote-control.md` runs Claude inside
  `core`.
- Host-native ("bare metal") Rails: the README states "Running Rails directly on the host is not
  supported", and `config/database.yml` fixes development hosts to `primary`/`replica`, which
  resolve only on the Compose network. However, the README's development URLs, the port-exposure
  document and the `core` port comment still describe host-native Rails on `:3000` using loopback
  datastore ports. The documents disagree; establish which is current before deciding.
- Observed in this session: Claude Code itself ran on the host, directly in the repository checkout,
  outside `core`.

## Option space

1. **Sandbox for agents only.** Keep `compose.yaml` and `core`; run AI agents in Docker Sandboxes
   with only the repository mounted. Smallest change; Rails still runs in `core`.
2. **Sandbox as the single environment.** Run agents, Rails and tooling inside sandboxes and retire
   `.devcontainer/` and host-native traces. Largest change.
3. **No Docker Sandboxes; harden the existing `core`.** Run agents only inside `core`, never on the
   host; add outbound allowlisting and keep host credentials out of `core`.
4. **Full virtual machine as the development environment.** Run Rails, Vite/Inertia, agents and
   Chromium natively inside a VM on the bare-metal host, with `compose.yaml` infrastructure running
   in rootless Podman inside the same VM. See "Option 4: virtual machine" below.

## Option 4: virtual machine

Status: added on 2026-11-06 at the owner's request; the owner is building the VM. Not decided. No
code, Compose or operations-document change is authorized by this section.

### Rationale (discussion on 2026-11-06)

- Isolation: the VM boundary contains a compromised gem, npm package or agent away from the host's
  home directory and root, which meets the rootless requirement without nested-container friction
  (for example the Codex bubblewrap failure inside rootless Podman).
- Required capabilities: Chromium runs natively in the VM, custom names resolve through the VM's
  `/etc/hosts`, and the VM console (SPICE or similar) replaces the Xvfb/x11vnc/noVNC desktop.
- Snapshots give a rollback point before dependency updates.
- Tailscale stays out of the VM; remote access, if needed, terminates on the host.

### Hypervisor

Prefer KVM (libvirt `qemu:///session` with virt-manager, or Quickemu) over VirtualBox. Inference, not
yet verified: VirtualBox's out-of-tree kernel modules tend to break on rolling-release host kernels
(the host runs Omarchy, kernel 7.2) and conflict with KVM.

### Intended layout

- Keep the repository checkout inside the VM and exchange changes through git; do not mount the
  host checkout through a shared folder, which would restore a write path to the host and slow I/O.
- Development and test credentials (`config/credentials/*.key`, `.env`, `gh` and agent OAuth state)
  must exist inside the VM. The VM protects the host, not the repository's secrets.
- Run `compose.yaml` services (PostgreSQL, Valkey, fakecloud) in rootless Podman inside the VM; run
  Rails, Vite and agents natively in the VM. `.devcontainer/` is not used on this path.
- Out of scope for the first iteration: OpenTelemetry and the observability stack, whose current
  behavior is unverified. The existing host-native transports remain available for later work:
  Alloy tails the read-only `./log` mount and publishes OTLP/HTTP on `127.0.0.1:4318`
  (`compose.yaml`, `alloy` service). Pipeline behavior beyond instrumentation output belongs to
  staging.

### Known blocker: fixed database endpoints

`config/database.yml` fixes development and test hosts to `primary`/`replica` and the port to
`5432`, while `compose.yaml` publishes primary on `127.0.0.1:5432` and replica on `127.0.0.1:5433`.
Mapping both names to `127.0.0.1` in `/etc/hosts` would route replica traffic to primary.
Candidates:

1. Proof of concept without code change: resolve `primary` to `127.0.0.1` and `replica` to
   `127.0.0.2`, and publish replica on `127.0.0.2:5432` through the untracked
   `compose.override.yaml` (the tracked file exposes the port, not the bind address).
2. Adopted layout: read database host and port from required environment variables with
   one-argument `ENV.fetch` (`adr/env-fetch-without-default.md`). This changes a deliberate
   Dev Container assumption and needs its own decision.

### VM prerequisites

Ruby 4.0.7 (`.ruby-version`), Bun 1.4.0 (`package.json` `packageManager`), `bundle install`,
`bun install --frozen-lockfile`, Playwright Chromium
(`node node_modules/playwright/cli.js install --with-deps chromium`), the credential keys and `.env`.
For the Rails browser E2E, `VALKEY_KVS_HOST=127.0.0.1` and `VALKEY_KVS_PORT=6381` satisfy the
loopback-only KVS rule in `docs/operations/rails-browser-e2e.md`.

### Acceptance for the proof of concept

1. `bin/rails test` passes inside the VM.
2. `bun run check` passes inside the VM.
3. `bun run test:e2e:rails` passes inside the VM.
4. Rails and Vite development servers start, and the VM's Chromium renders the `*.localhost`
   surfaces through Inertia.
5. Results, the commit and any uncommitted changes are recorded in `evidence/`.

If adopted, the same change resolves the host-native contradiction noted above and updates README,
`docs/operations/development-environment-setup.md`, `docs/operations/rails-browser-e2e.md` ("Run
inside the Dev Container") and the relationship to `adr/container-support-directory-podman-only.md`.

## Questions to answer before choosing

Owner-identified constraints on Docker Sandboxes:

- Engine: whether it works with Podman at all, or requires Docker; a switch to Docker reverses the
  Podman-specific decisions in `docs/operations/*`.
- Cost: whether it requires a paid Docker subscription (Docker Desktop licensing or a separate
  charge) for this use, now or as announced.
- Rootless: whether the sandbox and the engine behind it can run without root privileges on the
  host, matching today's rootless Podman. Rootless operation is a security requirement, not a
  preference: a compromise inside the environment must not gain host root.
- Accepted decisions: adopting Docker conflicts with
  `adr/container-support-directory-podman-only.md`; a successor decision must supersede it
  explicitly.

Further questions:

- Platform: whether Docker Sandboxes is supported on the Linux host in use, and whether it needs
  Docker Desktop or a Docker daemon alongside, or instead of, rootless Podman. Adopting Docker would
  reverse the Podman-specific decisions recorded in the operations documents.
- Reachability: whether a sandbox can reach `primary`, `replica` and Valkey on the Compose networks,
  and serve the `*.localhost` and tunnel host aliases that `core` carries today.
- Isolation actually gained: what the sandbox mounts, which credentials enter it
  (`config/credentials/*.key`, `.env`, `gh` and agent OAuth state), and whether outbound network can
  be restricted to an allowlist.
- What is lost: the noVNC browser desktop, Remote Control in `core`, the `workspace` target and the
  per-volume cache isolation.
- Editor: how the replacement editor connects (none of the above depends on VS Code except
  `devcontainer.json` customizations).

## Acceptance when resumed

- Record the verified Docker Sandboxes capabilities from primary sources
  (`generic/source-policy.mdc`) with versions and dates.
- Prototype the chosen option and record in `evidence/` that `bin/rails test`, `bun run check` and a
  browser sign-in through the tunnel work, and which credentials are present inside the sandbox.
- Resolve the host-native Rails contradiction and update README, `docs/operations/*` and
  `.devcontainer/` in the same change as the decision.

## Basis

Static reading at `b30345216886c98af1f04cbd434f067f12decf01` with uncommitted changes in the
worktree. Docker Sandboxes behavior was not checked against current documentation; no container,
sandbox or test was run for this note.
