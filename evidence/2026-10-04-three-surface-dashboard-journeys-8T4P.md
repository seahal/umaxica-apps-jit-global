# Three-surface Dashboard local authentication journeys

Executed on 2026-10-04, approximately 00:59–01:02 UTC, against feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with concurrent uncommitted work.
Used only the guarded `codex_integrity_20261003secret_*` disposable fleet.

Added `test/integration/base_dashboard_passkey_login_journey_test.rb` for app and
com. Each public HTTP journey starts at anonymous Dashboard, renders passive Base
Sign, explicitly posts with CSRF protection enabled, and validates the real signed
Jump target. A separate Auth cookie jar verifies a real WebAuthn assertion and
returns evidence without issuing a root Token. The original Base browser completes
canonical login, creates exactly one root Token, and follows the actual selector
response to a successful Dashboard. Region jp is used throughout the ceremony.

App currently returns an HTML Dashboard redirect from its selector; com returns
the existing JSON `next`. Tests follow each surface's current contract. The org
Entra-plus-Passkey journey also passes after replacing its dynamically defined
external transport methods with Minitest's public mock API. JWT/WebAuthn verification
and application login are not mocked; Microsoft HTTP/JWKS and Turnstile are the
external substitutions. Target delivery simulates the external Jump gateway.

Initial app/com attempts exposed incomplete test preconditions: current Passkey
login requires verified contact, and com Passkey persistence validates that contact.
Added verified synthetic email records while preserving those existing controls.
The first app record used the wrong status column; corrected to
`user_email_status_id`. An initial app selector assertion expected JSON despite
its current HTML redirect. These were test setup/expectation errors, not product
Red. No application authentication or response contract was weakened to pass.

## Actual verification

Command prefix: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test`.
Final selection:

- `test/integration/base_dashboard_passkey_login_journey_test.rb`
- `test/integration/base_org_dashboard_local_login_journey_test.rb`
- `test/integration/base_dashboard_authentication_guidance_test.rb`
- `test/controllers/base/local_authentication_entry_test.rb`
- app/com/org `test/controllers/base/<surface>/welcome_dashboard_authority_slice_1c_test.rb`
- `test/services/acme/selector_authority_test.rb`
- `test/integration/local_authentication_boundary_test.rb`
- `test/integration/auth_base_browser_authority_test.rb`

PASS: 98 tests, 951 assertions, no failures/errors/skips.
`bundle exec rubocop` on the two new Dashboard journey files: two files, no offenses.
Formatting was corrected without new suppressions or changed thresholds.
`git diff --check`: PASS before adding this evidence record.

## Limits

These are HTTP integration journeys, not real-browser or production gateway
execution. Arbitrary original fullpath restoration, other regions, browser history
and deployed routing remain unproven. No Secret, refresh, production configuration,
key or shared database changed here. The separately recorded 16 failures in the
old org Passkey suite remain unresolved; they were not included in this successful
selection and no global regression success is claimed.
