# APP social completion and method-page Back navigation

Date: 2026-11-02. Revision: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree contained
extensive uncommitted work, including earlier authentication changes; these observations describe
that worktree, not the committed revision alone.

## Observed changes and boundaries

- APP Email/Passkey/Secret Sign In and Email/Telephone Sign Up use the existing Page header Back
  anchor. ORG emergency Passkey uses the same localized `actions.back` label. Page supplies the
  decorative arrow. Cancel remains separate; method-selection entries receive no Back link.
- Public HTTP tests cover Apple and Google new-user signup through confirmation, birthdate,
  finalization, canonical authentication and the original RP's cookies and Dashboard. Existing-user
  sign-in cases also assert RP cookies and Dashboard. External-provider responses are fixtures; no
  live Apple/Google account or deployment was exercised. The RP completion cases no longer
  substitute a successful UserInfo response.
- Obsolete legacy tests expected a signup Flow before the verified callback. Tests now assert no
  Flow on provider dispatch and load the admitted Flow after callback. The test transport now
  permits unauthenticated public JWKS reads and cached reads. Canceled-browser callback expects the
  observed 403 after admission is removed, while retaining no-new-authority assertions.
- Social application issuance/state transitions were not changed. State, nonce, realm, admission,
  expiry, CSRF and ownership controls were not relaxed to satisfy tests.

## Executed checks

- `bin/rails test test/integration/social_login_admission_test.rb test/integration/social_signup_missing_flow_test.rb test/operations/social_auth_signup_finalizer_test.rb test/integration/email_signup_http_delivery_commit_test.rb test/integration/org_entry_cancellation_journey_test.rb`:
  **37 runs, 857 assertions, zero failures/errors/skips**.
- `bin/rails test test/integration/social_auth_app_flow_contract_test.rb`: **20 runs, 196
  assertions, zero failures/errors/skips**.
- Focused Vitest run for Contact signup, sign-in screens/interactions, APP Secret presentation and
  ORG screens: **5 files, 92 tests passed**.
- Scoped Oxlint on the four changed UI implementations and Contact/sign-in/Secret presentation
  tests: passed. ORG test-file lint was not included in that clean result; it contains an existing
  unused fixture declaration.
- Scoped Oxfmt check: passed; scoped `git diff --check`: passed.
- `bin/rails zeitwerk:check`: passed with the tool's warning that the vendored rails_db library is
  not eager-loaded and therefore is outside that check.
- Scoped RuboCop on four controllers and four integration files: **8 files, 20 offenses**. These
  include the existing Secret controller duplicate rescue branch and oversized legacy social
  transport/bootstrap helpers, implicit exception classes and a long line. They were not suppressed.
- A later combined run of all six Ruby files did **not** execute its 57 tests: database cloning
  failed with `PG::ObjectInUse` for `test_queue_db`. A single-worker retry then failed before tests
  with `ActiveRecord::NoDatabaseError` for `test_primary_db`. No sessions were terminated or
  databases repaired to force this check through. The two earlier successful runs remain distinct
  results, not a successful combined run.
- Consulted Apple's current Keyboards HIG Markdown at
  <https://developer.apple.com/design/human-interface-guidelines/keyboards.md>. Navigation retains
  native anchors; no custom keyboard handling was introduced. Actual browser focus, assistive
  technology, mobile and live-provider checks were not performed.

The entire repository Ruby suite and full-repository lint were not run for this scope. No schema
application, production/Neon operation, deployment or external write was performed.

## Open security/recovery gates

Normal completion does not establish recovery after Source commit followed by Ticket failure, nor
cross-tab callback-generation persistence. The existing proposals
`plans/2026-11-01-wua2-registration-completion-receipt-shape-review.md` and
`plans/2026-11-01-wua2-social-callback-generation-shape-review.md` explicitly require owner shape
approval (and the latter local migration approval). No proposed tables or writers were introduced or
applied. The owning spec remains open; these gates are not represented as completed or as production
readiness.

Implementation/tests discrepancy: legacy tests assumed pre-callback Flow creation, whereas the
implementation admits and verifies the provider callback first. The tests were corrected to the
actual boundary. Accepted recovery intent remains ahead of current persistence implementation, as
documented by the two open proposals; normal-path coverage does not resolve that discrepancy.
