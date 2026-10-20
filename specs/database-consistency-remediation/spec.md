# Database consistency remediation

Status: implementing

Authority: user request of 2026-10-19, phases 0–4 and completion conditions 1–10.

## Purpose and scope

Reconcile every database_consistency finding with the actual model, owning database and accepted
contract. Preserve valid behavior, security boundaries, audit history, identifiers and existing
work. Publishing and Avatar remain included. No checker exclusion, suppression, configuration
workaround, validation blanket, trigger introduction or production data transformation is
authorized.

## Acceptance

- AC-1: Capture an untruncated baseline, exit classification, versions, worktree, database/model
  mapping, migration status and stable finding ledger.
- AC-2: Each logical fix has contract grounds, characterization/regression evidence, relevant
  boundary tests and before/after full checker results. Keep unresolved findings visible.
- AC-3: All configured checker targets complete without internal errors and have zero findings.
- AC-4: Existing valid success/failure behavior and added regression tests pass; no weakened tests,
  unexpected deletion, session/authentication redesign or cross-database constraint is introduced.
- AC-5: Every migration has connection ownership, existing-data prerequisites, lock/rollback
  assessment, test-database rehearsal and generated-schema verification. Production prerequisites
  remain unverified until observed; local aggregate counts cannot establish production safety.
- AC-6: Record remaining checker/domain counts, root causes, models changed, migrations and tests.
  Preserve unrelated staged, unstaged and untracked work.

## Current disposition

AC-1 has baseline and catalog evidence in M8K2, corrected and expanded by R6J3; the ledger records
all 2,177 individual failures and the additional warning (2,119 CLI groups). AC-2 through AC-6
remain open. The standard identifier ADR specifies capacity 25 and generation 21; shrinking
PublicId::STORAGE_SIZE would contradict that contract. Final completion is unproven.

See [plan](plan.md), [ledger](findings.md) and [cycles](cycles.md).

Current user decisions: D1 preserves twelve Publishing duplicate-error contracts and D3 preserves
three historical token-reference lifecycles. All fifteen checker reports remain unresolved; neither
decision suppresses checks or establishes AC-3. See [decisions](decisions.md),
[public-ID inventory](public-id-review.md), [FK preflight](foreign-key-review.md), and
[index review](index-review.md).

## 2026-10-20 current disposition

AC-1 refreshed against the retained dirty worktree; see
[session evidence](../../evidence/2026-10-20-database-consistency-resumption-D8K4.md) and
[current stable-ID ledger](current-findings.md). AC-2 has completed bounded C10 verification: 24
digest-length reports removed, no new report. Remaining **1,886 individual failures and one
warning**; AC-3 through AC-6 remain open. The user reconfirmed retaining the duplicate-error and
public-ID capacity contracts. Schema comparison now stops at the HMAC definer-role/database-name
identity check; no complete schema-drift or migration-safety result is inferred.

## Required-field implementation update

Following the user's delegation of validation decisions, C11/C12 resolve 69 NOT NULL model findings
across 61 models without schema changes. Twelve new ColumnPresence reports reflect create-scoped
presence on an already NOT NULL publication timestamp; retain them to preserve projected-update
behavior. Latest checker: **1,829 individual failures, 1,814 displayed failures, one warning**. Full
completion, committed ownership test coverage and production migration acceptance remain open.

## Unique-index slice update

C13 inspects all 605 unique-index findings and resolves twelve Vocabulary.key preflight reports.
Latest counts: **593 UniqueIndex failures; 1,817 total individual failures; one warning**. The
accepted term-slug duplicate-error contract D1 remains unresolved. The index review distinguishes
PK-containing FK targets, partial predicates and NULLS NOT DISTINCT semantics. No blanket validation
or index removal is authorized. See [review](unique-index-review.md) and current evidence.

C13 terminal concurrent-worktree refresh: **569 UniqueIndex, 1,769 total individual failures and one
warning**. A separate newly introduced Publishing index-removal migration accounts for 24 unique and
24 redundant-unique reductions beyond C13's twelve. Final tests automatically migrated their test
database with it. See C13 cycle/evidence for attribution; do not count it as a C13 schema fix.
