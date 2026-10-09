# Compose Restart Recovery Budget Implementation Notes

## Context

- Original plan/spec: bounded failure recovery for `core`, `primary`, `replica`, and `valkey` in the
  development Compose stack, agreed in conversation on 2026-08-30.
- Related decisions/docs/plans:
  - `research/implementation/2026-08-23-cloudflare-tunnel-restart-storm.md` — the incident that set
    the current `on-failure:3` budgets and explicitly deferred `core`.
  - `docs/operations/container-engine-podman-notes.md` — "Restart policies", rewritten here.
  - `docs/operations/development-host-port-exposure.md` — unaffected; no publication changed.
- Implementation date: 2026-08-30.

## Decisions Made During Implementation

- Decision: `core` moves from `restart: always` to `restart: on-failure:5`.
  - Why: `always` was the last unbounded policy in the stack and the exact shape that produced ~2.8
    container recreations a second on 2026-08-23. `core`'s entrypoint
    (`/usr/local/bin/core-entrypoint`) can fail the same way. The 2026-08-23 note left this open
    because of a presumed interaction with the Dev Container `shutdownAction: stopCompose`; there is
    none, since an explicit stop suppresses either policy. That open item is now closed.
  - Alternatives considered: keeping `always` and containing the blast radius with resource limits
    only. Rejected — it leaves the loop itself running.
  - Follow-up needed: none.
- Decision: `primary`, `replica`, and `valkey` move from `on-failure:3` to `on-failure:5`.
  - Why: a slightly larger budget rides out transient failures without changing the incident
    economics; five attempts against a hard-failing container are still spent inside a couple of
    seconds.
  - Alternatives considered: leaving them at 3. Rejected only for uniformity with `core`.
  - Follow-up needed: `kafka` and `cloudflare-tunnel` stay at 3. They were outside the requested
    scope, and nothing about them argues for a different number; unify if either is touched again.
- Decision: `core`, `primary`, `replica`, and `valkey` gained a size-capped `json-file` log driver.
  - Why: this is the concrete resource bound the user asked for. Podman's rootless default is
    journald, which enforces no per-container cap, and a restart loop writes the same startup
    failure thousands of times. `cloudflare-tunnel` already carried this block; the shape is copied
    from it.
  - Alternatives considered: host-side journald rate limiting (`RateLimitIntervalSec`,
    `RateLimitBurst`), which the 2026-08-23 note also flagged. It is outside this repository and
    remains worth confirming on the host.
  - Follow-up needed: container output for these four services no longer appears in `journalctl`.
    Documented in the Podman notes.

## Deviations From Plan

- Change: none. The plan was implemented as approved.

## Rejected Alternatives

- A `healthcheck` for `core`. The Dev Container `core` runs `sleep infinity` and Rails is started by
  hand, so a port-3000 probe would report `unhealthy` through most of a normal session and would
  make `cloudflare-tunnel`'s dependency worse rather than better.
  `test/tooling/compose_restart_policy_test.rb` deliberately asserts nothing about it in either
  direction.
- `mem_limit`. `podman/psql-pub/postgresql.conf` sets `shared_buffers = 2GB` (replica `1GB`) with
  `max_connections = 2000` and `work_mem = 8MB`. A limit low enough to be useful invites an OOM kill
  mid-test, manufacturing the restart loop this change exists to bound.
- `pids_limit`. `core` runs Rails, Vite, pnpm, and parallel Minitest; a wrong value breaks work that
  succeeds today.
- Health-triggered recovery. Podman's `--health-on-failure=restart` has no Compose-file equivalent,
  so an alive-but-unhealthy container is still repaired by hand. Recorded in the Podman notes so the
  gap is not rediscovered.
- Promoting `core.depends_on.replica` from `service_started` to `service_healthy`. That is startup
  ordering, not recovery, and it would block the Dev Container from opening whenever streaming
  replication is degraded.

## Review Notes

- Tests run: `bin/rails test test/tooling` (19 runs, 90 assertions, 0 failures), including the new
  `test/tooling/compose_restart_policy_test.rb` (4 runs, 55 assertions). The new guard was also run
  against `HEAD`'s Compose files in a scratch tree, where three of its four assertions fail, so it
  pins the change rather than restating it.
- Unrelated environment finding: with the shell locale unset, `Encoding.default_external` is
  US-ASCII and `object_placement_test.rb` errors with `invalid byte sequence in US-ASCII` while
  reading pre-existing non-ASCII sources under `app/models` and `test/`. It passes under
  `LANG=C.UTF-8`. Nothing in this change is involved; the guard reads no file it touches. `core` now
  pins `LANG` and `LC_ALL` in `compose.yaml` at the user's request. The container was never the
  source of the problem — PID 1 already carries both from `Containerfile`'s `development-base`
  stage, and `/etc/environment` repeats them — so this hardens the setting against a build-target or
  base-image change rather than fixing the observed shell. The shells the agent harness opens arrive
  without them, which is a session/exec-layer behaviour outside Compose; run
  `LANG=C.UTF-8 bin/rails test ...` until that layer is addressed.
- Tests not run: everything requiring a container runtime. `podman` is not installed inside `core`,
  so `podman compose config`, the `podman inspect` policy readback, and the kill-and-recover drill
  on `global-devcontainer-valkey` must be run from the host shell and are unverified in this
  session.
- Documentation promotion needed: none. `docs/operations/container-engine-podman-notes.md` carries
  the durable statement; this note carries only the decisions.
