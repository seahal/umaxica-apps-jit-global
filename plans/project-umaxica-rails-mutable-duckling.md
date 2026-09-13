# Project Umaxica Rails — Six Workstreams Implementation Plan

## Context

Six workstreams were left unfinished across infrastructure and application code: an FDW feasibility
PoC, a local S3-compatible service, persistent remote-development access for both Codex and Claude
Code, Cloudflare ingress hardening, the centralized `publishing` CMS, and residual Passkey/WebAuthn
work. Phase 0 read-only audit (three parallel Explore agents) found most of these further along than
the prior context assumed — WS2 (RustFS), WS5 (publishing DB), and WS6 (Passkey) are largely
implemented, while WS1 (FDW), WS3 (Claude Remote Control specifically), and WS4 (Access JWT
validation) have no code yet. The audit also surfaced two correctness defects (empty
`publishing_structure.sql`, stale `operator_passkey.rb` annotation) that are not new scope but must
be fixed as a prerequisite gate before further WS5/WS6 work, since they risk a fresh database
bootstrap diverging from the migration-defined schema.

This plan sequences the remaining work into small, independently approvable gates, per your
instruction to divide Phase 2 into small approval gates and wait for explicit approval before any
file modification.

## Decision Log

| #   | Topic                           | Decision                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| --- | ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| D1  | FDW extension                   | Supabase Wrappers `s3_wrapper`. Read-only, RustFS-only, isolated disposable PoC image separate from `psql-pub`, fully removable.                                                                                                                                                                                                                                                                                                                                  |
| D2  | FDW PoC PG version              | PoC image pinned to **PostgreSQL 16**, not 17, because Wrappers' PG17 support is unconfirmed in current docs. This is isolated from `psql-pub` (17.7) by design, so no conflict with the permanent image.                                                                                                                                                                                                                                                         |
| D3  | FDW PoC scope                   | Feasibility question only: can this PG environment query CSV/JSONL/Parquet objects in local RustFS via Wrappers? Read-only smoke checks (SELECT, projection, filter, COUNT, missing-object, invalid-credential, schema-mismatch). No writes, no AWS S3 claims, no Rails/Active Storage/Shrine/CMS integration, no permanent app tests.                                                                                                                            |
| D4  | Claude Remote Control mechanism | Separate from the existing Tailscale/Codex SSH path (WS3A). WS3B runs `claude remote-control --spawn=same-dir` inside `core`, OAuth-only, outbound HTTPS/443 only, no dependency on the Tailscale sidecar. Shared infra limited to: host reboot recovery, rootless Podman availability, `core` lifecycle, persistent volumes, logging.                                                                                                                            |
| D5  | Reboot/autostart ownership      | User-level systemd unit templates + helper scripts + docs committed to repo. No Quadlet replacing the Dev Container stack — Dev Container remains canonical. Units call the existing supported Dev Container command, wait for `core` health, then start Remote Control with `Restart=always` (network-outage exits must auto-restart per documented ~10-minute timeout behavior). Host install/enable/linger/reboot test are manual gates you run.               |
| D6  | Cloudflare trust domains        | Tailscale (dev/operator), Cloudflare Tunnel (external Rails ingress), Workers VPC (Worker/Next.js → Rails), Cloudflare Access (perimeter for explicitly protected hostnames) — all retained as distinct, non-overlapping domains. Access JWT validation happens at the `cloudflared` connector via `originRequest.access` (audTag/teamName), not duplicated in Rails, unless Rails needs to consume Access identity for a specific feature (none identified yet). |
| D7  | `trusted_proxies`               | Not treated as a confirmed vulnerability. Reclassified as "client-IP handling requires verification." `bin/tunnel-origin-check` will be extended to observe the real header/IP path before any config change; only the immediate proxy or a narrowly proven subnet gets trusted, never broad Cloudflare IP ranges without evidence Rails sees them directly.                                                                                                      |
| D8  | Structure-dump drift            | Gate 0 for all WS5/WS6 permanent work. Regenerated only from disposable clean databases migrated from zero, never hand-edited, never regenerated from long-lived dev databases. Existing uncommitted Passkey files are preserved, not overwritten.                                                                                                                                                                                                                |
| D9  | Legacy production DROP          | Code-complete in scope (migration, safety checks, dev/test/disposable-prod-like execution, fresh-install verification, rollback docs, deployment checklist). Actual execution against a real production database is explicitly excluded from this engagement and gated behind a separate future manual approval.                                                                                                                                                  |

## Corrected Phase 0 Finding

WS4 `trusted_proxies` absence is reclassified from "gap" to **"client-IP handling requires
verification"** per D7 — investigate before configuring, not treated as a pre-decided fix.

## Dependency Graph

```
Gate 0 (structure-dump repair, disposable DBs)
  └─▶ Gate 5 (publishing legacy DROP code-complete)
  └─▶ Gate 6 (passkey annotation refresh)

Gate 1 (RustFS already implemented — verify only)
  └─▶ Gate 2 (FDW PoC, disposable PG16 image + Wrappers)
        └─▶ Gate 2c (FDW PoC teardown, retain docs only)

Gate 3a (WS3A Tailscale/Codex — audit only, no change planned unless you request one)
Gate 3b (WS3B Claude Remote Control systemd units) — depends only on Gate 0's unrelated verification
  of no regressions; otherwise independent of 3a, 4, 5

Gate 4a (bin/tunnel-origin-check extension — observe real header path)
  └─▶ Gate 4b (trusted_proxies + CF-Connecting-IP decision, evidence-based)
        └─▶ Gate 4c (Access JWT validation at cloudflared connector, only for protected hostnames)

Gate 5 depends on Gate 0. Gate 6 depends on Gate 0.
No workstream's permanent code depends on WS1 (FDW) or WS3 (remote dev) — those are infra-only.
```

## Proposed Gate Sequence

Each gate below is independently approvable. I will not proceed to a gate until you approve it, and
will state scope/files/commands/risks/rollback before starting each one.

### Gate 0 — Structure-dump repair (prerequisite for Gates 5 & 6)

- Capture `git status`, preserve all uncommitted changes.
- Identify every configured Rails DB/schema-format (`config/database.yml`).
- Build disposable clean databases, migrate from zero, verify schema/constraints.
- Regenerate `db/publishing_structure.sql` and every stale principals structure dump.
- Verify a fresh DB restores correctly from the regenerated dumps.
- Run migration + model tests.
- Regenerate `operator_passkey.rb` (and any other stale) schema annotations only after the above is
  green.
- **Files touched**: structure `.sql` dumps, model annotation comments only. No migration content
  changes.
- **Verification**: `bin/rails db:test:prepare`, `bin/rails test test/models`, targeted migration
  tests.
- **Rollback**: structure dumps and annotations are regenerated artifacts — revert via git if
  incorrect; no data risk since disposable DBs are used throughout.

### Gate 1 — RustFS verification (no code change expected)

- Confirm the `object-storage` profile still starts healthy, bucket-init/smoke rake tasks pass.
- Correct `docs/dds.md:289`'s false claim that Shrine uses RustFS.
- **Files touched**: `docs/dds.md` (doc correction only).

### Gate 2 — FDW PoC (disposable)

- New Dockerfile (e.g. `docker/fdw-poc/Dockerfile`, `FROM postgres:16-bookworm`) building
  `pgrx`/Wrappers via `cargo pgrx install`, isolated from `psql-pub`.
- New Compose overlay/opt-in profile (e.g. `fdw-poc` profile) wiring the PoC container to the
  existing RustFS network only.
- Temporary fixtures in RustFS: small CSV, JSONL, Parquet objects.
- Manual smoke checklist executed and recorded: SELECT, projection, filter, COUNT, missing-object,
  invalid-credential, schema-mismatch — per format.
- **Deliverable**: `docs/experiments/postgres-s3-fdw-poc.md` (English) — mechanism evaluated,
  reproduction steps, capabilities, limitations, operational/security concerns, suitability verdict,
  exact cleanup procedure. AWS S3 compatibility stated only as an unverified expectation.
- **Files touched**: new disposable Dockerfile + Compose overlay (removed in Gate 2c), new doc
  (retained).
- **Rollback**: Gate 2c removes everything except the doc.

### Gate 2c — FDW PoC teardown

- Remove PoC Dockerfile, Compose overlay, temporary SQL, RustFS fixtures, extension/server/user
  mapping/foreign table definitions.
- Retain only `docs/experiments/postgres-s3-fdw-poc.md`.
- Exact cleanup manifest recorded in the doc itself before removal, so the procedure is reproducible
  without relying on git history.

### Gate 3b — Claude Remote Control systemd templates (WS3B)

- New repo files (not installed automatically): user-level systemd unit template(s) — e.g.
  `docker/remote-control/claude-remote-control.service.template` — that:
  1. Bring up the Dev Container stack via the existing supported command.
  2. Wait for `core` health.
  3. Run `claude remote-control --spawn=same-dir` inside `core`.
  4. `Restart=always` (covers the documented ~10-minute network-outage exit).
  5. Log via the user systemd journal.
  6. Have no dependency on the Tailscale/Codex sidecar service.
- Companion helper script(s) and an English runbook (`docs/operations/claude-remote-control.md`)
  documenting the reboot test matrix and the manual host-side install/enable/linger/reboot-test
  commands for you to run.
- No secrets in unit files; auth/OAuth state lives in Claude Code's own credential storage inside
  `core`, referenced only, never embedded.
- **Files touched**: new template/script/doc files only; no `/etc` or host changes from inside the
  container.

### Gate 3a — WS3A Tailscale/Codex (audit-confirm only)

- No code changes planned; existing NOT-READY verdict from
  `plans/umaxica-rails-expressive-dewdrop.md` stands independently of WS3B. If you want the
  reboot-autostart gap for Codex closed too, that's a separate, explicitly scoped follow-up — flag
  if you want it folded in here.

### Gate 4a — `bin/tunnel-origin-check` extension (observation only)

- Extend the script to capture, without exposing secrets: `REMOTE_ADDR`, `request.remote_ip`,
  `X-Forwarded-For`, `CF-Connecting-IP`, immediate network peer, direct-origin-reachability test,
  and whether `cloudflared` overwrites or preserves client-supplied forwarding headers.
- Purely diagnostic — no `trusted_proxies` change yet.

### Gate 4b — `trusted_proxies` decision (evidence-based)

- Based on Gate 4a's captured evidence, configure the narrowest correct
  `config.action_dispatch.trusted_proxies` (immediate proxy or narrowly proven subnet only).
- Add a regression/contract test asserting direct origin access cannot forge `CF-Connecting-IP`.

### Gate 4c — Access JWT validation at connector (only if a protected hostname is designated)

- Configure `cloudflared` `originRequest.access` (`required`, `audTag`, `teamName`) for whichever
  hostname(s) you designate as Access-protected (e.g. an operator/internal surface).
- Rails-side Access JWT consumption only added if/when a specific feature needs Access identity —
  none is currently identified, so this stays out of scope unless you name one.
- Document all four request paths (browser+Access+Tunnel, public app, Worker-via-VPC, Tailscale dev)
  plus the Rails auth boundary in `docs/architecture/cloudflare-request-paths.md`.

### Gate 5 — `publishing` legacy-table DROP (code-complete, not executed in prod)

- Depends on Gate 0.
- Migration + preconditions/safety checks; run in dev/test and a disposable production-like DB;
  fresh-install verification; rollback/restoration doc; deployment checklist marking actual
  production execution as a later, separately-gated action.

### Gate 6 — Passkey annotation + any residual cross-surface gaps

- Depends on Gate 0.
- Regenerate `operator_passkey.rb` annotation (covered by Gate 0's last step) — confirm no other
  model annotations are stale for the 2026-07-19 migrations.
- Re-run `test/services/webauthn/verifier_uv_policy_test.rb`,
  `test/unit/security/webauthn_invariants_test.rb`, and surface-specific passkey tests to confirm
  the already-implemented invariants hold after Gate 0's schema regeneration.

## Test Strategy (per gate)

- Gate 0: `bin/rails db:test:prepare`, `bin/rails test test/models`, migration tests.
- Gate 1: `bin/rails object_storage:prepare`, `object_storage:smoke` rake tasks.
- Gate 2: manual smoke checklist only (no automated tests, per your explicit instruction).
- Gate 3b: no Rails tests; manual reboot test matrix (host reboot × login present/absent × Podman
  availability × container recreation × Remote Control restart × credential expiration × recovery
  command) executed by you per the runbook.
- Gate 4a/4b: `bin/tunnel-origin-check` output review; new request-spec/contract test for header
  trust boundary.
- Gate 4c: manual cloud verification checklist (Access-protected hostname reachable only with valid
  JWT).
- Gate 5: migration tests, fresh-install test, disposable production-like DB run.
- Gate 6: existing WebAuthn test suite, full pass required.

## Documentation Plan

- `docs/experiments/postgres-s3-fdw-poc.md` (Gate 2, permanent, English)
- `docs/operations/claude-remote-control.md` (Gate 3b, permanent, English)
- `docs/architecture/cloudflare-request-paths.md` (Gate 4c, permanent, English)
- `docs/dds.md` correction (Gate 1)
- `db/publishing_structure.sql` + principal structure dumps regenerated, not hand-authored (Gate 0)

## Security Review Checklist

- FDW PoC: read-only role, isolated network, no long-lived credentials left in RustFS/PG after
  teardown.
- Remote Control: OAuth-only enforced, no `ANTHROPIC_API_KEY`/`ANTHROPIC_BASE_URL` override, no
  inbound ports, `Restart=always` doesn't leak credentials into unit files or logs.
- Cloudflare: Access JWT validated at connector before reaching Rails; trusted_proxies narrowed to
  proven peers only; forged `CF-Connecting-IP` from direct origin access is rejected by test.
- Passkey: existing invariants (UV policy, opaque user handle, AAGUID advisory-only) re-verified
  post-Gate-0, not re-implemented.

## Known Limitations / Non-Goals

- No AWS S3 verification (RustFS-only PoC).
- No Rack::Attack revival (confirmed rejected, out of scope, untouched).
- No SimpleCov/coverage work, no IAM Identity Center, no unrelated repo work.
- Production DROP execution excluded from this engagement.
- WS3A (Codex) reboot-autostart gap not closed unless you explicitly fold it into Gate 3-series.

## Completion Criteria (per workstream)

- **WS1**: PoC executed for all 3 formats + failure cases, findings doc committed, all disposable
  artifacts removed and verified gone.
- **WS2**: `docs/dds.md` corrected; existing service verified healthy — otherwise already complete.
- **WS3**: WS3A status documented as-is (no change unless requested); WS3B units committed, host
  install performed by you, reboot test matrix executed and results recorded.
- **WS4**: evidence-based `trusted_proxies` set with regression test; Access JWT validation
  configured for any hostname you designate; request-path doc complete.
- **WS5**: structure dumps current, legacy DROP code-complete and verified in dev/test/disposable
  prod-like DB, production execution explicitly deferred.
- **WS6**: stale annotations fixed, full existing WebAuthn suite green post-Gate-0.
