# Auth ceremony admission rotation

- Date: 2026-09-22 UTC
- Repository HEAD: `277673d13547d722fc88f830711eee69b923a7e8`
- Branch: `feature`
- Worktree: already contained unrelated staged/unstaged and untracked changes; all were
  preserved. This slice added only the Auth ceremony model/controller tests and implementation
  named below.
- External writes: none. No GitHub, AWS, Cloudflare, provider, production, shared database,
  email, or SMS service was contacted.

## Change

`AuthCeremonySession.rotate_and_admit!` now revokes an existing predecessor and creates/admitted
the replacement in one writing-database transaction. The replacement records the predecessor
digest in the existing `previous_sid_digest` column. If a replacement from that predecessor was
already committed, another replacement attempt raises `AuthCeremonySession::InvalidTransition`.
The controller uses this public operation and maps that invalid transition to the existing invalid
admission response. A failed replacement insert therefore rolls back the predecessor revocation.

The operation remains Auth-local ceremony continuity. It does not create Base Browser Sessions,
RP Sessions, tokens, authorization codes, or policy authority. The separate CF-010 cross-store
Base/Valkey handoff blocker remains open.

## TDD and verification

The following public model tests were added before the implementation was completed:

- successful predecessor replacement and admission;
- predecessor preservation when the replacement violates the transaction-reference uniqueness
  constraint;
- rejection of a second replacement from the same predecessor.
- independent-connection concurrency with two replacement attempts, requiring exactly one success
  and one `InvalidTransition`.

The RED attempt and the post-implementation focused attempt were both run with:

```text
UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
PARALLEL_WORKERS=1 bin/rails test test/models/auth_ceremony_session_test.rb test/models/auth_ceremony_session_concurrency_test.rb
```

Both stopped during Rails test-schema boot before any test assertions because this execution
environment could not resolve the configured PostgreSQL host:

```text
ActiveRecord::DatabaseConnectionError: There is an issue connecting with your hostname: primary.
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

No localhost fallback, application-code bypass, test deletion, skip, mock substitution, or
database/configuration rewrite was used. Consequently, database-backed test results and the
concurrency behavior remain **UNVERIFIED** in this shell.

Static checks completed successfully:

- `ruby -c app/models/concerns/auth_ceremony_session.rb`
- `ruby -c app/controllers/concerns/auth_ceremony_admission.rb`
- `bundle exec rubocop app/models/concerns/auth_ceremony_session.rb app/controllers/concerns/auth_ceremony_admission.rb test/models/auth_ceremony_session_test.rb test/models/auth_ceremony_session_concurrency_test.rb`
- `git diff --check`
- `ruby /tmp/umaxica-frozen-plan/validate_plan.rb` reported `result: PASS` with zero mapping,
  closure, or placeholder errors after the plan amendment.

## Remaining boundary

The predecessor-row lock serializes replacement attempts when the browser presents a persisted
predecessor. A first admission with no predecessor has no row to lock and remains part of the
separate CF-010 coordination decision; this slice does not claim a browser-wide distributed lock.

At the time of verification the process was in a Podman container, but `getent hosts primary` and
`getent hosts valkey-kvs` returned no records and the `podman` executable was unavailable. The
Compose core-service network could therefore not be reached from this shell; no hosts file,
Compose setting, application setting, or fallback address was changed.

The non-secret preflight checks found `config/credentials/test.key` present and all requested
PostgreSQL/Valkey variable names defined in `.env.devcontainer.example`; no variable values or
credential contents were printed. The prescribed environment-check command still failed when it
attempted to connect to PostgreSQL at the unresolved `primary` host.
