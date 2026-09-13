# Delivered OTP Autocomplete Implementation Notes

## Context

- Original plan/spec: conversation plan for limiting `autocomplete="one-time-code"` to delivered
  email and telephone OTP inputs.
- Related decisions/docs/plans: repository surface and testing rules; no ADR or stable documentation
  defines this HTML attribute.
- Implementation date: 2026-07-18

## Decisions Made During Implementation

- Decision: remove `one-time-code` from TOTP enrollment, TOTP sign-in challenge, TOTP step-up
  verification, and organization invitation inputs.
  - Why: those values are not delivered email or telephone OTPs and must not receive unrelated code
    suggestions.
  - Alternatives considered: setting `autocomplete="off"`; rejected because omission is the
    requested minimal behavior.
  - Follow-up needed: none.

## Deviations From Plan

- Change: render the com step-up email OTP template through its controller renderer for the DOM
  assertion instead of reaching it through an edit request.
  - Why: after OTP issuance, the current com verification gate redirects the edit and update
    requests back to method selection. Changing that authentication workflow is outside this task.
  - Risk: the assertion verifies the generated DOM but does not add new end-to-end coverage for the
    existing com redirect behavior. Existing com verification request tests remain unchanged and
    passing.
  - Follow-up: investigate the com email step-up redirect separately if direct browser reachability
    is not intentional.

## Review Notes

- Tests run: targeted delivered OTP request tests, Base identity OTP integration tests, and full
  affected TOTP controller tests.
- Tests not run: the complete repository test suite was not rerun for this view-only boundary
  change.
- Documentation promotion needed: none.
