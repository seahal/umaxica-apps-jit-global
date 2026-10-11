# Rails test regressions

## Decisions

- Follow `docs/architecture/flat-ruby-source-layout.md` for the eleven publishing model concerns:
  move them directly under `app/models/concerns`, flatten their constants with the `Publishing`
  prefix, and update consumers. Keep the layout guard unchanged. Association class names still
  derive from each concrete model's family, preserving the twelve independent publishing family
  table sets.
- Follow `docs/operations/db-workflow.md`: restore `db/app_ticket_structure.sql` to the same
  session-setting stub as the other committed dumps. The populated dump contradicted this documented
  contract and its existing regression test. No database was modified by this file edit; migrations
  remain the reconstruction authority.
- Update the health title test for the current plain-text response header, already covered by the
  health endpoint tests.
- Replace the removed promotion index constant assertion with public-operation behavior checks
  across all twelve content families. Stub only the association lookup/insert boundary to report a
  competing insert; verify recovery for the revision index and propagation for every other unique
  index discovered from the database.

## Verification

See `evidence/2026-09-06-rails-test-regressions.md` for completed checks and limitations.
