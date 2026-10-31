# Local development Passkey inventory

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes. Both read-only commands used `RAILS_ENV=development` and the repository's configured development databases, whose configured host is `primary`.
- Grouped retained Passkey counts: app 0 rows / 0 owners / 0 owners above 10; org 0 rows / 0 owners / 0 owners above 10. Both model connections reported that their Passkey table has no `slot` column.
- No production or Neon data was queried. No migration, backfill or database write was performed by these checks. The checked-in Zenith structure dump files inspected separately contain no table definitions and therefore do not substantiate the current database shape.
