# Critical gate closure audit

- Date: 2026-09-23
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing staged, unstaged, and untracked changes were preserved.
- External activity: no AWS, Cloudflare, GitHub, provider, production, or shared-database access
  was performed.

## Scope and order

The Frozen Plan at `plans/backlog/2026-09-17-integrated-hardening-plan.md` was used as the SSOT.
For each of `CF-003/CF-004`, `CF-005`, `CF-007`, and `CF-011`, the required inputs, closure
condition, minimum evidence, current implementation/topology, and adversarial failure modes were
checked before considering any implementation. No code, configuration, migration, registry, key,
provider, or deployment change was made.

The adversarial review found that the closure table needed three explicit proof constraints: owner
cutover must prove a unique post-cutover source of truth; the regional RP conflict must be resolved
by an ADR amendment before implementation; and processor delivery terminal states must be observable
and immutable. The Frozen Plan was amended with those constraints. This is a plan clarification,
not a blocker closure.

## CF-003 / CF-004 — owner mapping and cutover

### Requirements and current state

Required authoritative owner data and an approved source-to-owner mapping are not available. The
test-scoped read-only inventory reported:

```text
authority_schema_state=applied
resources_scanned=0
classifications={}
```

An explicit development read-only run reported four local rows:

```text
classifications={inactive_principal: 2, membership_not_ownership: 2}
```

Those rows are not authoritative production ownership data. No approved lifecycle/conflict rules,
backfill mapping, cutover procedure, rollback procedure, or post-cutover source-of-truth proof was
available.

### Adversarial review

Inferring ownership from identity binding, first membership, `primary` membership, or legacy
operator references could assign resources to the wrong actor or create dual authority. An empty
test inventory cannot prove that production rows are safe to migrate. A migration that leaves both
legacy and adopted ownership relations authoritative would make authorization decisions ambiguous.

### Decision

**OPEN — DECISION REQUIRED**

Required to resume: authoritative source data, approved mapping and conflict/lifecycle rules,
migration/cutover/rollback procedure, and evidence that post-cutover each owned resource has one
approved authoritative relation or an explicit ownerless disposition. No owner was inferred or
backfilled.

## CF-005 — production worker and scheduler topology

### Requirements and current state

The local configuration check passed:

```text
RAILS_ENV=test bin/jobs check
Solid Queue configuration is valid.
```

Local queue configuration and bounded test pickup are repository-side evidence only. No authorized
production worker, dispatcher, scheduler, queue assignment, production DB topology, or
production-equivalent end-to-end execution evidence was available in this audit.

### Adversarial review

Successful enqueue or configuration parsing does not prove that a production worker receives and
executes the job. A missing scheduler, wrong queue assignment, unavailable DB connection, or worker
duplication could leave expiry, retention, or enforcement work unprocessed or multiply it. A local
test run cannot establish those production facts.

### Decision

**OPEN — EVIDENCE REQUIRED**

Required to resume: an operations-owned topology record and a non-destructive, production-equivalent
end-to-end execution check covering worker pickup, scheduler recurrence, retry/failure behavior,
DB access, and the rollback/runbook path. No production access was attempted.

## CF-007 — regional RP identity

### Requirements and current state

The local static registry currently contains:

```text
core-app, core-com, core-org,
side-app, side-com, side-org,
edit-org
```

It does not contain JP/US-specific client IDs, independent regional URI sets, or independent
regional private-key bindings. `core-next-rp` remains a live compatibility bridge and is mapped to
the same local `CORE_APP` key namespace as `core-app`. The accepted seven-RP ADR records the
regional conflict as unresolved.

### Adversarial review

Inventing regional IDs, redirect URIs, audiences, key names, or credentials could cause cross-region
credential acceptance, redirect mismatch, logout misrouting, or premature `core-next-rp` retirement.
Changing the local registry alone would not prove Base registration or deployed caller migration.

### Decision

**OPEN — DECISION REQUIRED**

Required to resume: an ADR amendment resolving the seven-client/regional conflict, the approved
JP/US client and host matrix, the global `edit-org` exception, independent key/credential mapping,
Base registrations, deployed caller inventory, and the `core-next-rp` migration order. No regional
client or external registration was invented.

## CF-011 — processor delivery

### Requirements and current state

The repository still has no approved concrete processor adapter, authenticated receipt contract,
retry-exhaustion rule, or permanent-failure state. The success allowlist remains empty. Unsupported
processor notifications remain an explicit `processor_unavailable` failure and are not marked
`NOTIFIED`.

The focused processor/authority set passed, including the existing retry-window and terminal-state
guards. That proves current fail-closed behavior and state protection; it does not prove delivery.

### Adversarial review

Adding a guessed adapter or treating request acceptance as delivery would create false success.
Without authenticated receipts, replayed or forged provider responses could complete an erasure
notification incorrectly. Without bounded retry exhaustion and an immutable permanent-failure
state, the system could retry forever or claim completion after an unresolved failure.

### Decision

**OPEN — DECISION REQUIRED**

Required to resume: approved adapter/authentication, idempotency, receipt authentication,
transient/permanent taxonomy, retry and exhaustion rules, immutable terminal state, audit, and
manual-recovery contract. Contract tests must cover forged receipts, duplicate delivery, retry
exhaustion, permanent failure, and recovery before any provider verification.

## Verification

Focused command:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/queries/authority_owner_migration_inventory_test.rb \
  test/models/authority_schema_contract_test.rb \
  test/services/oidc/client_registry_test.rb \
  test/services/oidc/token_exchange_service_test.rb \
  test/jobs/processor_erasure_notification_job_test.rb \
  test/models/processor_erasure_notification_state_test.rb
```

Result: `151 runs, 981 assertions, 0 failures, 0 errors, 0 skips`.

Full command:

```text
bin/rails test
```

Result: `11540 runs, 73472 assertions, 0 failures, 0 errors, 8 skips`.

The skips and expected OmniAuth diagnostics were not modified. `git diff --check` passed after the
Frozen Plan clarification. These test results do not satisfy any of the four external/data/topology
closure conditions by themselves.

## Resumption-input scan

After the closure audit, the repository's `plans/`, `docs/`, `adr/`, `evidence/`, `config/`,
`app/`, and `lib/` trees were searched for newly available owner datasets or approvals, regional
client/key matrices, production topology evidence, and processor receipt/retry contracts. No new
authoritative input was found. The matching files remain the existing audits that explicitly record
the missing input, not evidence that the input has since been supplied.

Accordingly, no implementation was started in this resumed cycle and no gate status changed.
