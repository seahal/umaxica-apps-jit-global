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
