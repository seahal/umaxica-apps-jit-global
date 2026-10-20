# Retire the isolated PostgreSQL test fleet

Status: closed

Accepted by the repository owner on 2026-10-20: stop using the repository's isolated database mode
and manifest workflow. This is a local test-infrastructure change, not database cleanup authority.

## Purpose and scope

Use the ordinary configured `test_*` databases for Minitest and Rails browser E2E. Remove the
per-run PostgreSQL name selector, parent manifests, worker receipts, isolated worker lifecycle and
the isolated-fleet rebuild command. Keep effective-target safety checks, migration reconstruction,
real COMMIT/concurrency assertions, browser CSRF and provider boundaries, and Valkey namespaces.

The existing ordinary parallel database cloner remains. Rails' default schema-loading worker
preparation is not an equivalent replacement: migration-created reference rows and identifier-HMAC
function ownership are absent from structure dumps. That issue is separately tracked in
`plans/backlog/2026-10-20-reference-data-outside-migrations.md`. This change does not repair it or
claim a complete return to Rails-standard database preparation.

The closed [browser E2E foundation](../rails-browser-e2e/spec.md) describes the predecessor. Its
isolated-clone startup/cleanup requirements are intentionally replaced here; historical verification
of the predecessor is preserved. The current browser scenario is read-only and may use ordinary test
storage under an exclusive process lock. Future mutable scenarios require their own data lifecycle.

## Acceptance

- AC-1: Effective test database names remain the ordinary configured names, without PostgreSQL
  isolation variables or a manifest file. Development and production configuration is preserved.
- AC-2: No executable consumer invokes the isolated creation, verification or cleanup path. The
  rebuild command is removed. Existing databases, roles and receipt files remain untouched.
- AC-3: Minitest can load the affected Avatar collection without requiring run-owned worker
  receipts, including with `PARALLEL_WORKERS=1`. Existing real-COMMIT and independent-connection
  assertions remain; scoped test cleanup is preserved.
- AC-4: Browser startup checks the ordinary test catalog and actual pool targets, retains CSRF,
  provider/egress boundaries and scoped Valkey cleanup, and performs no PostgreSQL creation or
  deletion. Browser and Minitest processes coordinate through the same existing ordinary lock.
- AC-5: Current operational instructions describe the replacement, retained ordinary cloner,
  committed-data persistence and separately authorized recovery. Historical records are preserved.

## Execution and verification

1. Remove isolated runtime branches and their consumers, preserving the normal cloner.
2. Switch browser bootstrap to the ordinary configured targets and shared process lock.
3. Update current operations documentation and record the replacement decision.
4. Run syntax/lint, effective configuration and safety-refusal checks, a narrow Avatar test and
   browser verification where available. Record actual results and limitations in `evidence/`.

No Minitest/Vitest environment-construction tests are added. No destructive rebuild, bulk cleanup,
production operation, new database backend or reference-data migration is authorized. Existing
committed-data contamination is a test-environment limitation, not permission to weaken a constraint
or silently reset storage. Material unverified acceptance keeps this specification open.

## Acceptance disposition

Evidence: [Q8P4](../../evidence/2026-10-20-isolated-test-fleet-retirement-Q8P4.md).

- AC-1: passed; normal configuration equality and 62 effective connection checks.
- AC-2: passed; isolated consumers and rebuild command removed; existing resources retained.
- AC-3: passed; 44 Avatar tests and 203 assertions on ordinary databases with one process.
- AC-4: passed for the current public scenario; Chromium rendering, startup checks, graceful
  cleanup, non-test refusal and shared-lock contention verified.
- AC-5: current operations docs and
  [replacement ADR](../../adr/ordinary-test-databases-without-isolated-fleet.md) updated.

Full-suite and actual parallel-worker execution, CI, deployment and destructive cleanup were not
performed. These are not completion claims. The ordinary cloner and known schema-loading limitation
remain explicitly within the replacement contract.
