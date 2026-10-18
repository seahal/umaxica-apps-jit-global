# Final integrated hardening handoff

- Date: 2026-09-17 UTC
- Repository: `seahal/umaxica-apps-jit-global`
- Branch: `feature`
- Starting task HEAD: `3ff5241c4b876c2c828e772c0fd289c8aae5f850`
- Ending HEAD: `48ae9707597716c8d0b3af1433a08ba1f1a85f75`
- Pre-existing worktree changes preserved: `README.md` modified, `misc.md` and `refactor.md`
  deleted, and the browser-block notification files untracked. They were not staged or committed.
- No GitHub, remote branch, deployment, production/shared datastore, or external provider write was
  performed.

## Passing checks

- `bundle check` — passed.
- `bundle exec rubocop` over the 223 existing Ruby files changed by this task — passed with no
  offenses. Deleted historical paths were excluded from the successful rerun.
- `bundle exec ruby test/tooling/evidence_layout_test.rb` — passed: 3 runs, 6 assertions.
- `bundle exec bin/rails zeitwerk:check` — passed; Rails reported that all eager-loaded paths are
  valid, with only the existing optional `rails_db` warning.
- `bundle exec bin/jobs check` — passed: `Solid Queue configuration is valid.` This validates
  configuration only and does not prove worker execution.
- `bun run format:check` — passed for 571 files.
- `bun run lint` — passed.
- `bun run typecheck` — passed.
- `bun run test` — passed: 85 files and 1,057 tests.
- `git diff --check` and `git diff --cached --check` — passed for each local task commit.
- Static searches found no application assignment of `request.request_id` to `trace_id` or
  `Actor.trace_id`, no queue wildcard/anchor in `config/queue.yml` or `config/recurring.yml`, and no
  production call site deleting an authored ownership row.
- `git diff --check` — passed.

## Blocked or unverified checks

- The focused Rails authority test was attempted with explicit loopback test Valkey URLs using
  logical databases 3/4/5. Rails reached PostgreSQL, but all three tests stopped before assertions
  because the test surface schema lacks the existing `organizations` relation
  (`PG::UndefinedTable`). The configured `valkey` service did not respond to readiness checks.
- The authored authority migrations were not executed. Ownership transfer/lifecycle behavior, direct
  SQL deletion behavior, rollback/concurrency proofs, and current-data owner inventory are
  unverified.
- Solid Queue worker/dispatcher/scheduler pickup, delayed/recurring/retry integration, and external
  OIDC delivery remain unverified.
- Production/development boot checks requiring deployment secrets and infrastructure were not
  claimed.

## Security boundary confirmed by static review

- `request_id` remains Rails HTTP correlation; `trace_id` and `span_id` are emitted only from a
  valid OpenTelemetry SpanContext. Analytics consent does not alter technical correlation IDs.
- OIDC endpoint realm is fixed by the controller and required by direct coordinator callers before
  code consumption or refresh rotation. RP revocation remains surface-local and lock-ordered.
- Existing access JWTs may remain usable until natural `exp` plus verifier leeway; immediate access-
  JWT revocation is not claimed.
- OTP success consumption and resend cooldown are serialized; sign-up expiry remains request-time
  authoritative even if Solid Queue is stopped.
- The six authored ownership models reject independent Active Record destruction. This is not a
  complete authority cutover or a direct-SQL protection mechanism.

## Remaining conflicts

`CF-002` (test boundary), `CF-003` (authority cutover and owner mapping), `CF-004` (lifecycle
clocks), `CF-005` (worker runtime), `CF-007` (regional RP registration), `CF-008` (scrub inventory),
`CF-009` (approved request-body contract), and `CF-010` (Auth/Base issuance handoff) remain
documented in `conflict.md`. The accepted Chronicle crash gap remains documented; no transactional
audit outbox was added.
