# dependent: :delete_all foreign keys changed to ON DELETE CASCADE

Date: 2026-10-20 HEAD: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829` Worktree: uncommitted changes from
the 2026-10-19 and 2026-10-20 database_consistency work and unrelated pre-existing edits were
present.

## Change

Decision (user, 2026-10-20): deleting a parent row deletes the rows that depend on it. Seven foreign
keys whose parent model already declares `dependent: :delete_all` were replaced with
`ON DELETE CASCADE` foreign keys (added with `validate: false`, old constraint removed, validated in
a separate migration):

- com_zenith (`db/com_principals_migrate/20261020100000`, `...100001`):
  `visitor_processor_erasure_notifications.visitor_privacy_request_id`,
  `visitor_withdrawal_flow_events.visitor_withdrawal_flow_id`,
  `visitor_withdrawal_ceremonies.visitor_id`
- app_zenith (`db/app_principals_migrate/20261020100000`, `...100001`): the matching three
  `client_*` columns
- op_base_com (`db/op_base_com_migrate/20261020100000`, `...100001`):
  `visitor_verifications.visitor_token_id`

Not changed: `Visitor.visitor_tokens` crosses databases; recorded in
`plans/backlog/2026-10-20-cross-database-atomicity-refactoring.md`.

## Results

- First attempt derived constraint names longer than PostgreSQL's 63-byte limit, so validation could
  not find them. The development databases were restored by hand and explicit shorter names used.
- Development DBs: migrate, rollback of both migrations, and reapply passed for all three.
- Schema dumps: only the seven constraint replacements and the two schema_migrations rows were
  applied to the existing dumps. Sorted index and foreign key statements matched dumps regenerated
  from the migrated databases.
- `bundle exec database_consistency`: 1754 → 1747. ForeignKeyCascadeChecker: 8 → 1
  (`Visitor visitor_tokens`).
- Test DBs migrated. 188 test files referencing the affected models: 1718 runs, 0 failures, 0
  errors.

## Open point

Withdrawal flow events and processor erasure notifications are audit or compliance records. They
were already deleted with their parent by the model; whether they must outlive it is left to
`plans/backlog/2026-10-19-withdrawal-final-deletion-and-retention.md`.
