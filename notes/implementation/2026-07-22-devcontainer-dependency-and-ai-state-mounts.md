# Dev Container Dependency and AI State Mounts Implementation Notes

## Context

- Original plan/spec: `plans/chatgpt-pro-compose-scalable-mochi.md`
- Related decisions/docs/plans:
  - `.devcontainer/devcontainer.json`
  - `.devcontainer/compose.override.yml`
  - `docs/operations/remote-codex-over-tailscale.md`
  - `docs/operations/claude-remote-control.md`
- Implementation date: 2026-07-22

## Decisions Made During Implementation

- Decision: Let `Gemfile`, `Gemfile.lock`, and `package.json` inherit the writable workspace bind
  mount, while keeping `.github`, `bin`, and `.devcontainer` on explicit read-only binds.
  - Why: Bundler updates `Gemfile.lock`, and pnpm replaces `package.json` atomically. Per-file bind
    mounts prevent those normal update operations with `EROFS` or `EBUSY` even when the workspace
    itself is writable.
  - Alternatives considered: Bundler frozen mode preserves a read-only lockfile for install-only
    workflows, but it intentionally prevents the dependency update workflow required here and does
    not solve pnpm's `package.json` replacement.
  - Follow-up needed: Verify effective mount flags after the next operator-owned Dev Container
    recreation.

- Decision: Replace the host read-write binds for `~/.claude` and `~/.codex` with persistent named
  volumes.
  - Why: Both tools need writable credential and state storage, but they do not need authority to
    modify the host copies of those directories. A compromised `core` process can still read
    credentials from the mounted volumes, so this is host-mutation isolation rather than
    credential-theft prevention.
  - Alternatives considered: Making the tool directories read-only breaks login refreshes and state
    updates. Retaining writable host binds preserves host state sharing but grants unnecessary host
    mutation authority.
  - Follow-up needed: Sign in inside the recreated container if the new volumes do not already
    contain credentials.

- Decision: Remove the host bind for `~/.claude.json` instead of attempting to mount a named volume
  at a file path.
  - Why: Named volumes are directory mounts. Current Claude OAuth credentials persist under
    `~/.claude`, while the home-level JSON file is auxiliary state that can be regenerated in the
    container writable layer.
  - Alternatives considered: A broad named volume over `/home/global` would also persist this file
    but would widen the state and mount-order boundary well beyond this task.
  - Follow-up needed: Recreate any container-local Claude MCP or auxiliary state that was previously
    supplied only through the host `~/.claude.json` file.

## Deviations From Plan

- Change: The original plan described `~/.claude.json` as the authentication file and proposed
  retaining it as a writable host bind.
  - Why: The current credential location and the approved host-isolation goal no longer support that
    assumption.
  - Risk: Auxiliary Claude state stored only in `~/.claude.json` does not survive Dev Container
    recreation.
  - Follow-up: Promote a different persistence mechanism only if a concrete required setting cannot
    be stored under the named-volume-backed `~/.claude` directory.

## Review Notes

- Tests run:
  - `podman exec --workdir /home/global/workspace global-devcontainer-core env -u RUBY_DEBUG_OPEN bin/rails test test/unit/security/devcontainer_mount_contract_test.rb`
  - `podman compose -f compose.yaml -f .devcontainer/compose.override.yml config`
  - JSONC-subset parsing of `.devcontainer/devcontainer.json`
  - `devcontainer read-configuration --docker-path podman` against the proposed configuration
- Tests not run:
  - The host-side Rails test command could not boot because the host lacks `libvips.so.42`; the same
    focused test passed inside the already-running container.
  - No Dev Container recreation or live effective-mount check was performed, because the operator
    explicitly deferred all Podman and container restarts. The already-running container therefore
    retains the previous effective mounts until that operator-owned recreation occurs.
- Documentation promotion needed: None. Stable operational behavior is recorded in the two related
  runbooks.
