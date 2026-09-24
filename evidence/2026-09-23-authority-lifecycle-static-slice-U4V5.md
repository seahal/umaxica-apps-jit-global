# Authority lifecycle pre-deployment static slice

- Date: 2026-09-23
- Commit: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: already contained unrelated staged, unstaged, and untracked changes; none were reset,
  cleaned, staged, committed, or sent to GitHub for this slice.
- Scope: CF-003/CF-004 pre-deployment implementation only. No production, provider, AWS, Cloudflare,
  or external registry was accessed or changed.

## Implemented and statically verified

- Six concrete lifecycle models were added, one per approved resource family:
  `ClientPersona`, `Enterprise`, `Individual`, `Company`, `Agent`, and `Bureau`.
- Three surface-local migrations create the six lifecycle tables with concrete resource foreign
  keys, `ON DELETE RESTRICT`, a finite checked state vocabulary, a database-clock
  `state_changed_at`, and one lifecycle row per resource.
- New resource creator operations insert an explicit `active` lifecycle row in the same writer
  transaction as the resource and owner relation.
- Existing-resource lifecycle backfill requires an explicitly reviewed state, is surface-local,
  idempotent for the same state, and rejects replacement of an existing different state.
- Owner inventory treats a missing lifecycle row as unresolved. The family cutover guard fails
  closed for missing, non-active, or otherwise unresolved lifecycle/owner state.
- Ruby syntax checks passed for all changed lifecycle models, operations, inventory, migrations,
  and focused tests.
- Targeted RuboCop passed for the changed lifecycle models, operations, migrations, inventory,
  and focused tests: 19 files, no offenses; the subsequent schema-contract test amendment also
  passed targeted RuboCop.
- Full Brakeman passed with 0 errors and 0 security warnings.
- `git diff --check` passed.

## Adversarial review of this slice

- Multiple, zero, inactive, cross-surface, membership-only, administrator-only, and legacy-only
  owner candidates remain rejected or manual-review inputs; the direct backfill operation requires
  an explicit surface-local owner and has no tie-breaker.
- Repeated lifecycle backfill for the same state is idempotent; a different existing state is a
  conflict. The resource lock and one-row-per-resource unique index are the intended concurrency
  boundary, but the independent-connection PostgreSQL proof is still unverified here.
- A missing or non-active lifecycle row cannot satisfy the family guard. No consumer switch or
  rollback marker was added in this slice, so there is no newly introduced partial consumer cutover;
  the absence of that mechanism remains an explicit CF-003/CF-004 implementation gap.
- The six lifecycle tables are concrete and surface-local. No shared owner table, polymorphic
  owner reference, legacy `Organization` to `Bureau` inference, or lifecycle-based owner transfer
  was introduced.

## Environment verification

The required environment file was selected without printing secret values. The test credential key
was present and all required PostgreSQL/Valkey variable names were present. The current process had
`/run/.containerenv`, but `primary` and `valkey-kvs` did not resolve through DNS. The required
preflight was executed:

```text
bundle exec ruby -r ./lib/local_environment -e 'LocalEnvironment.load!; load "scripts/test-environment-check"'
```

It failed before Rails test boot with:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

Because preflight failed, no focused Rails test or full Rails suite was run in this process. No
application/configuration workaround, localhost substitution, test deletion, skip, mock, or
security weakening was used.

## Remaining acceptance gap

This evidence does not close CF-003/CF-004. Complete reviewed owner backfill, isolated PostgreSQL
migration/concurrency/rollback proof, an explicit family-level consumer cutover mechanism, and
post-cutover forward-recovery proof remain required. The new schema dump files could not be
regenerated or checked because the required PostgreSQL service was unreachable.
