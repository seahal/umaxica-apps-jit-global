# Security Report: Session Fixation Through the Base OIDC Result Retry

Date: 2026-10-20. Status: open, escalated for security review. Reported against commit
`2b23e9d20c61c695a5eb2353cbca70f9d900d3f4` (worktree had unrelated uncommitted changes). Evidence:
`evidence/2026-10-20-session-fixation-result-retry-S7F3.md`. No code has been changed.

## Summary

An attacker who can place a Base session cookie of their choosing in a victim's browser can, after
the victim signs in, obtain fresh authentication cookies for the victim's root session and an OIDC
authorization code, without completing any authentication ceremony. `reset_session` runs at sign-in,
but the Base OIDC result retry branch reissues credentials to any browser that still holds the
pre-login browser nonce, and that nonce survives the rotation.

The behavior was reproduced with `rails test` on the app and com surfaces. The org surface runs the
same code and is presumed affected; it was not probed.

## Severity

Treated as high: the outcome is full session takeover of the victim's root login. Exploitation needs
two preconditions (below), which lower likelihood in production but must not be relied on as the
control. The issue must be fixed before any production deployment.

## Affected code

- `app/controllers/base/{app,com,org}/oauth/authorizations_controller.rb`,
  `finalize_authorization_transaction!`: when `base_finalized_at` is present, it calls
  `reissue_login_credentials_for_existing_session` for `browser_session_ref`.
- `app/services/base_auth_admission_coordinator.rb`, `validate_result_browser_binding!` and
  `result_root_context_matches?`: the retry is admitted when the browser nonce digest matches and
  `binding.base_token_id == token&.id`. For an anonymous start both sides are nil, so a browser
  without authentication cookies passes.
- `app/controllers/concerns/base_admission_browser_binding.rb`,
  `ensure_base_admission_browser_nonce!`: an existing session nonce is reused rather than replaced.
- `app/controllers/concerns/oidc_authorization_result_post.rb`: after finalization the nonce is
  written back into the rotated session, so it keeps matching across `reset_session`.

## Attack sequence

1. The attacker opens Base and starts an authorization, so their session holds a browser nonce.
2. The attacker plants that session cookie in the victim's browser.
3. The victim signs in. Base reuses the planted nonce, finalizes, rotates the session and issues the
   victim's cookies.
4. Within the result validity window, the attacker uses their copy of the old cookie with the
   victim's `result_ref` and `transaction_ref`: GET the result continuation, then POST it.
5. Base takes the retry branch, issues new authentication cookies to the attacker, and a following
   `/oauth/authorize` issues an authorization code.

## Reproduction

A temporary copy of `test/integration/base_dashboard_passkey_login_journey_test.rb` recorded the
Base `session` cookie and the result continuation path immediately before the victim's final POST,
then replayed them from a separate integration session after the victim's success. Observed on both
app and com: the continuation GET returned 200, the POST returned 303 with a newly issued access
cookie, and `/oauth/authorize` redirected to `/oidc/callback` with a `code`. The victim's token
stayed active. The probe file was deleted after the run.

## Preconditions and existing mitigations

- Cookie placement: production uses `__Host-session` (host-only, Secure), which blocks injection
  from sibling subdomains and plain HTTP. Remaining avenues include XSS on the Base host, local
  access to the browser or device, and malicious browser extensions. Development and test use a
  domain-scoped `session` cookie.
- Reference disclosure: `result_ref` and `transaction_ref` travel in URLs. The attacker must obtain
  them while the result is valid (`Valkey::AuthState::OpaqueAdmissionStore::CODE_TTL`, 60 seconds,
  and the transaction must not be expired). URL-borne values can reach logs, telemetry, history and,
  in development, the Inertia devtools recorder.
- CSRF protection does not help: the attacker submits from their own browser with a valid token for
  the planted session.

## Comparison: local completion is not affected

`BaseLocalAuthenticationCompletion#complete_local_login_response!` returns 409 for an already
finalized flow unless the current session owns the issued token. It does not reissue credentials to
another browser. The OIDC retry branch should not be more permissive than this.

## Remediation options for review

1. Reissue on retry only when the request already carries the finalized session
   (`current_session&.public_id == browser_session_ref`); otherwise refuse, as local completion
   does. This removes the takeover. A legitimate browser that lost the response would have to
   restart the sign-in.
2. Rotate the browser nonce at sign-in and stop restoring it after finalization, so a pre-login copy
   no longer matches. This narrows the attack but keeps reissuance bound to a bearer value.
3. Make the result single-use for credential delivery and drop the reissue branch entirely.

Option 1 is the recommended baseline; options 2 and 3 can be combined with it. The review must also
decide whether `ensure_base_admission_browser_nonce!` should ever reuse a nonce from an
unauthenticated session, and whether `OIDC_RP_SESSION_KEYS` carried across `reset_session` create a
comparable path.

## Required tests

- For each surface (app, com, org), an integration test in which a browser holding the pre-login
  session cookie replays the finalized result after the victim's success and receives no
  authentication cookie and no authorization code.
- For each surface, a test that a value planted in the pre-login Base session is absent after
  sign-in, except for explicitly preserved keys.
- A test that the legitimate browser's retry behaves as the chosen remediation specifies.

Only behavioral evidence of rotation currently exists indirectly (`Set-Cookie` presence in
`org_oidc_auth_handoff_root_completion_test.rb` and `email_signup_base_root_completion_test.rb`); no
test asserts that pre-login session state is discarded.

## Related findings from the same session

- `switch_handoff` is not single-use within its two-minute TTL; it is bound to the browser nonce, so
  it inherits the same nonce-survival weakness. No test covers its replay, expiry, foreign browser
  or surface mismatch.
- The OIDC exit continuation page's `no-referrer` policy makes its same-origin POST fail the origin
  check (`plans/backlog/2026-10-20-oidc-exit-continuation-null-origin.md`).
- The Inertia devtools recorder (development only) stores URLs with `switch_handoff` unredacted.

## 2026-10-20 addendum: interim destructive containment

This incident is treated as a serious security incident. The original investigation above is
preserved as a historical record; its statements that no code was changed describe that earlier
investigation, before the containment work recorded here.

An interim containment measure has now been implemented locally against commit
`2b23e9d20c61c695a5eb2353cbca70f9d900d3f4`, with uncommitted containment changes and other
pre-existing uncommitted work. This is not a deployed mitigation or a declaration of incident
closure.

- Removed `reissue_login_credentials_for_existing_session`, `rotate_existing_session_credentials`,
  `install_reissued_login_credentials`, and the exclusively used `find_browser_session_for_oidc`
  from `AuthenticationBase`.
- Replaced the finalized-result reissuance branches on app, com and org with a refusal returning
  `status: :login_failed` under the existing transaction lock, before any new root login issuance.
- Removed the retry-only browser nonce save and restoration from `OidcAuthorizationResultPost`.
- Preserved the initial root login issuance path, its `reset_session`, normal refresh-token
  rotation, initiation browser binding and database schema. Existing tests were left unchanged; no
  recovery, fallback or compatibility implementation was introduced.

This is an intentional breaking change, not a completed recovery design. A finalized OIDC result can
no longer recover credentials or resume authorization-code issuance through the removed retry path
after a lost response. Other tabs relying on the old browser nonce may also lose their ability to
continue authentication after the first tab completes. Normal sign-in, sign-up to sign-in
continuity, session-limit and cooldown effects, and multi-tab behavior remain unverified at runtime
after removal.

Redesigning the paths that guide users through authentication, interruption, refusal, restart and
completion is mandatory follow-up work. As part of the system's metabolism, retiring an unsafe
mechanism requires deliberately rebuilding the user journey around the resulting boundaries and
failures. That redesign must account for lost responses, finalized-result retries, sign-up to
sign-in continuity and concurrent tabs without restoring the removed credential reissuance
mechanism. It belongs to a separate design cycle and has not been implemented in this containment
change. This requirement records the incident follow-up decision, not a verified system property.

### Verification and limits

Static searches found none of the four removed method names in `app/`. Ruby syntax checks passed for
all five changed implementation files, and `git diff --check` passed. A comparison with the
start-of-task file hashes showed changes only in those five implementation files and no changes to
test files during containment.

Two existing-test commands were attempted with `bin/rails test`: one for
`oauth_oidc_authority_test.rb`, `oidc_result_browser_binding_test.rb` and
`oidc_result_csrf_transport_test.rb`; another for the selected sign-in, root issuance, sign-up
completion, session-limit/cooldown and CSRF invariant tests. Both exited with status 1 before test
execution because database preparation raised:

```text
POSTGRESQL_TEST_PREPARE_DATABASES contains unverified databases:
test_app_ticket_db, test_com_ticket_db, test_org_ticket_db
```

This is an environment failure (category E), not an observed authentication assertion failure.
Existing tests expecting successful finalized-result retries conflict intentionally with the removal
(category A in intent), but their assertions were not reached. No environment adjustment or test
modification was made to bypass the failure. The earlier reproduction results above are not
post-containment validation.

Code inspection shows the finalized-result credential reissuance path has been removed on all three
surfaces. Post-containment attack replay has not been executed. First-completion races,
pre-authentication session cookie copying, browser-binding validity and other credential issuance
paths remain separate security concerns; this removal does not establish that session fixation as a
whole has been resolved.
