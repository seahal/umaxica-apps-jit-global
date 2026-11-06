# WU-A2 social callback state local inventory

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this record was added, the worktree had 508
modified or untracked paths and no staged changes. Existing work was preserved; no commit was
created.

Ran read-only Rails runner queries against the local OP Base App development and test databases with
`.env.container.devcontainer` loaded. Counts used each database's own clock to classify unconsumed
rows by expiry:

| Environment | Total callback-state rows | Unconsumed | Unconsumed, unexpired | Unconsumed, expired | Provider / intent       |
| ----------- | ------------------------: | ---------: | --------------------: | ------------------: | ----------------------- |
| Development |                         0 |          0 |                     0 |                   0 | none                    |
| Test        |                         3 |          3 |                     0 |                   3 | Google / null intent: 3 |

The query printed only counts and provider/intent groups, not state values. It changed no rows and
accessed no production, Neon or external database. These generic callback-state rows cannot be
reliably assigned to a sign-up Auth Ceremony or parent; no such inference or backfill was made. The
separate proposed-generation shape is documented in
`plans/2026-11-01-wua2-social-callback-generation-shape-review.md`. No migration or test suite was
run for this inventory.
