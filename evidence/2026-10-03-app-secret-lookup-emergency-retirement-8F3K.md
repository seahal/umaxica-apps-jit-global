# app Secret lookup and Emergency placeholder retirement

Executed on 2026-10-03, approximately 23:09–23:18 UTC, against feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with concurrent uncommitted work.
Tests used only the task-owned `codex_integrity_20261003secret_*` disposable fleet.

## Lookup implementation

ClientSecretLookupQuery validates exact 32-character Base58, uses the existing
whole-value HMAC lookup digest with the unique index, and verifies the selected
credential's complete Argon2 password. Eligibility is evaluated on the writer with
writer database time. Pending, claimed, revoked or discarded credentials return
no candidate. No contact identifier or public ID is required as an input.

The query performs no claim, mutation, failed-attempt update, account authorization
or session issuance. Its result cannot replace atomic claim; a concurrent change
must be revalidated by the eventual claim operation. No HTTP caller is connected
until that trusted flow/browser binding is available. Infrastructure errors are
not rescued into an ordinary unknown-Secret result.

`bundle exec ruby /tmp/umaxica-secret-db-task.rb test
 test/queries/client_secret_lookup_query_test.rb`:

- Red: 4 missing-class errors after successful database/fixture preparation.
- Green: **4 tests, 23 assertions, no failures/errors/skips**. Covers multiple
  credential owners, 31/32/33 lengths, nil/empty/zero/array/hash/NUL/alphabet/case
  partitions, unknown values, terminal states, no mutation, and a digest-only match
  whose password does not match.

## Retired app Emergency entry

Removed only app's placeholder GET resource, its controller, menu item and unused
app authentication translations. The old placeholder tests now require route
absence rather than guest-only display. Route helper/menu expectations are aligned
with that approved retirement. Org's Emergency routes are unchanged.

The historical app Emergency commit-acknowledgement ADR is marked superseded by
the accepted integrated contract, preserving its text and the remaining irreversible
claim/session-proof requirement.

- Red for the new HTTP retirement test: expected 404, actual 200 placeholder.
- Initial lookup/retirement/route-contract selection: 14 tests, 454 assertions, no
  failures/errors/skips.
- Expanded selection added Auth route naming, app Sign menu and replaced placeholder
  tests: **41 tests, 783 assertions, no failures/errors/skips**.

Commands used the same isolated wrapper and named test files. No gate was weakened,
no compatibility route added, and no authentication success was mocked for the new
lookup or retirement tests. Existing menu/route test harnesses retain their previous
setup; these results do not establish a real browser journey.

RuboCop inspected nine affected Ruby files: one interpolation quote offense remained
in the new retirement test and was corrected with a file-local autocorrection.
The lookup test's assertion-spacing offense was also corrected. `git diff --check`
passed. No DDL or external application was performed in this slice.

Canonical GET/POST Secret Sign in, atomic claim, durable flow correspondence,
receipt writing, delivery and other old app Secret callers remain incomplete.
The absence of the old Emergency entry is not reported as a working new Secret login.
