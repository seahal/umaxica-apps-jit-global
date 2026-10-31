# WU-A3 local admission binding inventory

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked changes were
present. Read-only Rails queries used `RAILS_ENV=test` and verified test-prefixed database names.

The local app OP database contained 124 admission bindings: 101 unredeemed and unretired,
23 redeemed, zero retired. The 23 redeemed bindings referred to 23 existing admitted sessions;
zero of those sessions had a cancellation timestamp. The local org OP database contained zero
bindings. Counts are point-in-time test observations and do not describe production data.

Inspected the binding lifecycle, Switch handoff, issuance and purger. The current lifecycle uses
nullable timestamps, and the model has no `switched` transition. Cancellation alone does not
prove that a legacy session ended by Switch. No backfill, schema change or deletion was performed.
The unresolved shape and contract conflict are recorded in `four.md`.
