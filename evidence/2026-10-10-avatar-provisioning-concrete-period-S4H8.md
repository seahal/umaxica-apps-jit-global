# Concrete Avatar provisioning slice

- Commit under test: `2a1644f73238839ed7ed513bd4681ea393a86682`.
- The worktree contained pre-existing and current uncommitted changes; they were preserved.
- Database: disposable PostgreSQL catalog from
  `tmp/acceptance-isolated-20261009social3.json`; Rails ran with `PARALLEL_WORKERS=1`.

The first Red added a public provisioning assertion that an app-owned Avatar has an
`AvatarEnterpriseOwnershipPeriod` beginning at `Avatar.created_at`; it failed because provisioning
only wrote the legacy `AvatarOwnershipPeriod`. The Green change writes the concrete Enterprise or
Bureau period in the same transaction while retaining the legacy period for the staged reader
transition.

Commands and results:

- `bundle exec rubocop app/services/avatar_provisioning/create.rb test/services/avatar_provisioning/create_test.rb`
  — no offenses.
- `bundle exec rails test test/services/avatar_provisioning/create_test.rb
  test/operations/avatar_ownership_transfers_test.rb` — `15 runs, 91 assertions, 0 failures,
  0 errors, 0 skips`.

This slice does not claim that legacy transfer readers/writers have been cut over to the concrete
period tables; that remains a later transition requirement.
