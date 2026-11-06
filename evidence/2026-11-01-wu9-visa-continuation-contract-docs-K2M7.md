# WU-9 Visa continuation contract documentation

Updated the Design D amendment and current authentication/security documents to match the Visa
authorization continuation implementation: result, cancellation, switch, and silent-SSO GETs
validate and render a signed same-origin form; the existing authorization POST revalidates and
commits the operation. The earlier state-consuming Design D GET rules remain scoped to their named
Auth admission/handoff continuations. No application code changed in this slice.

Verification performed:

- `git diff --check` passed.
- A targeted search for the stale claim that Visa result GET consumes or commits the result returned
  no matches in `adr/`, `docs/`, and `.agents/harnesses/rules/`.
- `PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS= VALKEY_NAMESPACE_RUN_ID=codex-visa-post-doccheck-20261101 PARALLEL_WORKERS=1 bin/rails test test/integration/visa_authorization_continuations_test.rb test/integration/oidc_initiated_sign_in_completion_test.rb:84 test/integration/oidc_initiated_sign_in_completion_test.rb:121`
  passed: 8 runs, 176 assertions, 0 failures, 0 errors, 0 skips.
- The full test suite was not run in this documentation slice.

The work was performed at HEAD `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree already
contained uncommitted changes; `git status --short` reported 432 entries before this evidence file
was added. No commit was created.
