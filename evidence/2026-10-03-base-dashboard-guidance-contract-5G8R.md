# Base Dashboard guidance and passive Sign contract

Executed on 2026-10-03, approximately 23:41–23:48 UTC, against feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with concurrent uncommitted changes.
Only the task-owned `codex_integrity_20261003secret_*` disposable fleet was used.

## Contract reconciliation

The current RootsController show actions already declare private authentication
on app/com/org. An initial selection of guidance and three Welcome/Dashboard
files ran 67 tests and 464 assertions, with six failures: anonymous direct
Dashboard and invalid-cookie Dashboard partitions in each surface still expected
404, while the application returned 302 to the same Base's `/sign`.

The approved replacement is recorded in
`adr/base-secret-core-contract-precedence.md`. Updated only those stale anonymous
Dashboard expectations to assert the exact same Base host, `/sign`, region and
no-store response. Authenticated Home's 404 and resource-integrity errors remain
separately tested. This is a specified contract replacement, not a claim that
changing expectations fixed an application defect. No controller changed here.

Expanded the public guidance test with real persisted Tokens and signed access
cookies on all three surfaces. With CSRF protection enabled, authenticated GET
and HEAD `/sign` render passively, while a valid-CSRF new POST is terminally
refused with 403. Flow count and Token status, deadline, refresh digest and
Step-Up timestamp remain unchanged. Anonymous POST without CSRF is refused before
admission issuance. Existing HTML, JSON, Inertia and HEAD Dashboard cases remain.

Explicit anonymous POST was also exercised with real local admission and Jump
issuance: exactly one flow is created. JWT.decode verifies ES384 signature using
the repository's test public key, configured issuer and configured audience;
the signed target is the matching Auth `/sign/in` with the correct region and
entry reference. A distinct Auth request session accepts that target without
issuing a root Token. Only target delivery is simulated: the external gateway and
its return-token verifier are not executed in this journey.

## Actual commands and results

All Rails commands used `bundle exec ruby /tmp/umaxica-secret-db-task.rb test`.

- Initial guidance plus three Welcome/Dashboard files: 67 tests, 464 assertions,
  six obsolete-expectation failures, no errors/skips.
- After replacing those expectations: 67 tests, 569 assertions, no failures,
  errors or skips.
- Expanded guidance alone: 21 tests, 177 assertions, no failures/errors/skips.
  Intermediate setup errors used the wrong Visitor Token kind column and
  Nokogiri Element#fetch; corrected without changing application behavior. These
  are not product Red evidence.
- Final selection: guidance; app/com/org Welcome/Dashboard and RootsController
  files; BaseLocalAuthenticationEntryTest; JumpRtIssuerTest, return policy and
  return verifier files; JumpGatewayBoundaryInvariantTest. PASS: **231 tests,
  1,315 assertions, no failures/errors/skips**.
- Additional existing LocalAuthenticationBoundaryTest and
  AuthBaseBrowserAuthorityTest: PASS, **7 tests, 112 assertions**, no failures,
  errors or skips. These include app/com Auth evidence, canonical Base issuance,
  separate browser refusal, replay and scoped Passkey continuation. Their existing
  Jump transport/signing substitutions are not represented as real gateway tests.
- Final RuboCop on the guidance file and three changed Welcome/Dashboard files:
  PASS, four files with no offenses. `git diff --check`: PASS.

## Limits

The combined selection does not complete an org authentication ceremony or a
real browser. Existing app/com completion tests do not begin at Dashboard and
finish all selector steps to render Dashboard, so complete three-surface return
acceptance remains unproven. Completions currently use their declared Dashboard
success path; arbitrary original fullpath restoration is not demonstrated.
No new return protocol, refresh behavior, external routing, shared DB application
or deployment was introduced. Existing image-response behavior was inspected but
not changed or included in this command selection.
