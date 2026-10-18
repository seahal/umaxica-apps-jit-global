# Environment-Test Retirement Implementation Notes

## Context

- Original plan: frozen `one.md`, “Environment test retirement” (DEC-078).
- Related decision: `adr/no-test-suite-for-environment-construction.md` and
  `.agents/harnesses/rules/project/no-environment-tests.mdc`.
- Implementation date: 2026-10-13.

## Decisions Made During Implementation

- Deleted the three environment-construction tests named by the frozen plan, with no replacement
  Minitest or Vitest case. Before deletion, development was booted and its configured
  `ActionDispatch::HostAuthorization` middleware was probed through `Rack::MockRequest`; the
  observed host/status groups are recorded in
  `evidence/2026-10-13-environment-test-retirement-A6V9.md`.
- The current Host Authorization docs disagreed with the actual development policy. In particular,
  the Core ADR said `jp.umaxica.*` was rejected, while development boot accepted those configured
  public hosts. The probe also showed `core-jp.umaxica.app` and `evil.example.com` return 403. The
  three current documents were updated to match this observation and to describe the check as
  point-in-time evidence, not a regression guard.
- `docs/architecture/cloudflare-request-paths.md` said the deleted test checked Compose alias to
  `PUBLIC_*_URL` consistency; inspection of the test showed it did not. The document now assigns
  that configuration check to direct inspection when those boundaries change.
- Kept `test/config/test_environment_edge_contract_test.rb`; its application-behavior cases passed
  13 tests and 68 assertions through the isolated Rails test path. The deleted isolation-contract
  file mixed setup assertions with database-safety reporting/catalog probes. The frozen plan
  explicitly retires it wholesale without replacements; this removes direct coverage of those
  specific reporting/catalog cases from that file.
- `test/test_helper.rb` still has a comment naming the deleted host-configuration consistency test.
  It was not edited because `.agents/harnesses/rules/generic/testing.mdc` prohibits editing that
  file while changing tests. A separate test-infrastructure cleanup can remove the stale comment.

## Deviations From Plan

- None to the three file deletions or documented manual verification. The Host Authorization probe
  exposed a stale statement in the existing Core ADR; the ADR was corrected to the observed
  configured-host behavior.

## Review Notes

- Tests run: retained environment edge behavior test; exact results in the evidence record.
- Tests not run: the deleted environment-construction tests, as prohibited by the accepted rule; the
  full Rails suite remains for the later plan step.
- Documentation promotion needed: none beyond the three current documents updated in this change.
