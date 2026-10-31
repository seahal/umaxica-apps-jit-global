# Local test Passkey inventory

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes. The read was against `RAILS_ENV=test`; its contents are transient test data.
- A read-only Rails runner grouped retained Passkeys by owner and printed aggregate counts: app 0 rows, 0 owners, 0 owners above 10; org 12 rows, 6 owners, maximum 2, 0 owners above 10.
- No development or production database count was obtained. No schema, backfill, or data was changed by this check.
