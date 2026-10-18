# Core browser API Origin enforcement

Executed on 2026-10-03 (UTC), against feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with concurrent uncommitted changes.
Tests used only the task-owned `codex_integrity_20261003secret_*` disposable fleet.

## Finding and change

The API's explicit CSRF callback verified the token without verifying Origin.
Rails' general forgery callback is separately configurable. A request with a valid
session CSRF token, no Origin and same-site metadata reached refresh processing.
The existing TrustedOriginForgeryProtection already refuses that combination;
all three Core API bases now include it explicitly. The API callback requires both
valid_request_origin? and Rails' verified_request_for_forgery_protection?, in
addition to its existing explicit token requirement. No validator was created.

The implementation uses the fixed local Rails source at revision
`2f75a03b05aff2610b3799ef9ebd87cfc9cf38eb`, not a moving edge guide. General
callback ordering, safe methods and refresh protocol semantics are unchanged.

## Actual execution

`bundle exec ruby /tmp/umaxica-secret-db-task.rb test
 test/integration/core_browser_origin_boundary_test.rb`:

- Red: missing Origin with same-site metadata expected 403 but got 401, showing
  that the request reached the existing unauthenticated refresh response.
- Initial Green: 2 tests, 18 assertions, no failures/errors/skips.
- Expanded Red: exact Origin with contradictory cross-site metadata got 401.
  Requiring the existing Rails Fetch Metadata verification corrected this.
- A later real-credential test initially used nonexistent Visitor token fixtures;
  that test setup error was corrected using a real Visitor and token. It is not
  counted as a product Red or hidden by a fixture/helper change.

Combined command added the existing Core browser API boundary, surface and RP
browser-flow files: **36 tests, 311 assertions, no failures/errors/skips**.
All three surface hosts reject sibling/foreign Origins, different scheme/port,
null/malformed Origin, and contradictory metadata. Same-origin valid-CSRF POST
continues to return the existing 401 when a refresh cookie is absent.

Real app/com/org RP credentials were issued through their existing model APIs.
A rejected foreign-Origin POST preserved digest, deadline, previous-generation
absence, rotation absence and unrevoked state. No token exchange was mocked for
these refusal tests. Existing accepted refresh tests in the combined selection
also passed; this is not proof of new refresh behavior or browser continuity.

No external writes, DDL, browser execution, Edge repository changes, or CloudFront
routing/cache application occurred. Secret claim/payload approval gates remain
independent of this change.

RuboCop on the concern, three API bases and new test passed (5 files, no offenses)
after test-only formatting corrections. `git diff --check` passed.
