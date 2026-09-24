# Lifecycle-aware owner quota boundary

- Date: 2026-09-23
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: existing unrelated changes were preserved; no commit, reset, clean, or external write
  was performed.

## Change

`Acme::AccountQuotaPolicy` and `Acme::OrganizationQuotaPolicy` now enforce the approved
surface-local lifecycle boundary:

- only explicitly `active` owned resources count;
- an inactive/retained/discarded/deleted owned resource does not consume the active quota;
- an owner with a missing lifecycle row fails closed;
- an inactive, suspended, or access-blocked principal cannot use the quota policy;
- selector/switcher membership and delegated act-as resolution is unchanged.

The six concrete resource/lifecycle mappings remain explicit in the two existing policies. No
shared authority table, polymorphic relation, lifecycle fallback, or new external service was
introduced.

## TDD and verification

Before the production change, public policy tests were added for inactive resources, missing
lifecycle rows, and inactive principals. The focused Rails command was attempted with the explicit
devcontainer environment and one worker, but Rails stopped during schema boot because the current
process could not resolve `primary`:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

No assertion result is claimed from that attempt. Ruby syntax checks and targeted RuboCop passed for
the two policies and their tests; `git diff --check` passed. No test was deleted, skipped, weakened,
or replaced by a mock. The DB-backed focused test remains unverified until the configured Compose
PostgreSQL/Valkey network is available.

## Scope status

This closes the previously deferred lifecycle filtering inside the owner-specific quota policy
slice. It does not close CF-003/CF-004: family-wide reviewed backfill, named authorization
consumer cutover, and post-cutover forward recovery remain separate requirements.
