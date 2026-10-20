# Session Fixation Review of Sign-In Session Rotation

Date: 2026-10-20. Commit: `2b23e9d20c61c695a5eb2353cbca70f9d900d3f4`. The worktree had uncommitted
changes, including `app/services/base_auth_admission_coordinator.rb` (association lookups in
`admission_base_token_record` and `admission_root_actor`); they do not touch the branch exercised
below. Only `rails test` was used; no browser or deployed environment was involved.

## Rotation inventory (code reading)

- Every interactive sign-in and sign-up issuance calls `AuthenticationBase#log_in`, which reaches
  `bind_committed_login!` and calls `reset_session` before the authentication cookies are written
  (`app/controllers/concerns/authentication_base.rb`). Callers: Base app/com/org
  `oauth/authorizations_controller.rb#login_for_oidc`, `LocalAuthenticationSessionCommitter`,
  `base/app/sign/in/limitations_controller.rb`,
  `base/app/social/authentication/completions_controller.rb`, `AuthenticationSequenceGate`,
  `BaseSignInLimitations`, `OidcCallback` (RP session).
- `set_login_auth_cookies` is called only from `apply_committed_login!` (after
  `bind_committed_login!`) and `install_reissued_login_credentials` (after its own `reset_session`).
- Values carried across the reset: `OIDC_RP_SESSION_KEYS` (`oidc_code_verifier`, `oidc_state`,
  `oidc_nonce`, `oidc_pt`, `oidc_pending_flows`), and, in `OidcAuthorizationResultPost`, the Base
  admission browser nonce (`auth_admission_browser_nonce`) after a finalized result.
- `BaseAdmissionBrowserBinding#ensure_base_admission_browser_nonce!` reuses a nonce already present
  in the session.
- Production uses the `__Host-session` cookie (host-only, Secure); development and test use
  `session` with a domain.

## Probe

A temporary copy of `test/integration/base_dashboard_passkey_login_journey_test.rb` (app and com
surfaces; deleted after the run) recorded the Base `session` cookie and the Auth result continuation
path just before the victim browser completed Base finalization. After the victim's completion
succeeded, a separate integration session holding only that recorded cookie:

1. GET the result continuation path: 200, the continuation form rendered.
2. POST the form: 303; an access cookie was set (a newly issued value, not the victim's copy).
3. GET `/sign` and posted the RP start form; `/oauth/authorize` redirected to `/oidc/callback` with
   a `code` parameter, i.e. Base treated the session as authenticated without any ceremony.

Observed output (both surfaces identical): `attacker POST result: 303`,
`attacker access cookie present=true`, `attacker authorize -> .../oidc/callback code_issued=true`,
`victim token still active=true`. The suite reported 2 runs, 0 failures.

## Finding

`reset_session` runs, but the Base OIDC result retry branch defeats it. In
`base/{app,com,org}/oauth/authorizations_controller.rb#finalize_authorization_transaction!`, a
transaction with `base_finalized_at` calls `reissue_login_credentials_for_existing_session` for the
finalized browser session. The only browser proof is
`BaseAuthAdmissionCoordinator.validate_result_browser_binding!`: the browser nonce digest, and
`result_root_context_matches?`, which returns true when `binding.base_token_id == token&.id`; both
are nil for an anonymous start and an attacker without authentication cookies. Because the nonce is
reused when present and restored after rotation, a pre-login session cookie copy keeps passing the
binding.

Preconditions for an attacker: placing a chosen Base session cookie in the victim's browser before
completion, and obtaining the victim's `result_ref` and `transaction_ref` while the result is valid
(`OpaqueAdmissionStore::CODE_TTL` 60 s, transaction not expired). `__Host-session` blocks
cross-subdomain and network cookie injection in production.

The org surface has the same branch (code reading only; not probed). The local completion path
(`BaseLocalAuthenticationCompletion`) returns 409 for an already finalized flow unless the current
session owns the token, and was not affected by code reading.

No code was changed.

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

## 2026-10-20 addendum: removal of remaining pre-login session carry-over

At the user's explicit instruction for this incident, further code was removed without test changes
and without TDD. Tests were not modified and not run for this step; existing tests that rely on the
removed behavior are expected to fail.

- `AuthenticationBase#bind_committed_login!` no longer preserves `OIDC_RP_SESSION_KEYS`
  (`oidc_code_verifier`, `oidc_state`, `oidc_nonce`, `oidc_pt`, `oidc_pending_flows`) across
  `reset_session`; the constant and `preserved_oidc_rp_session_state` /
  `restore_oidc_rp_session_state!` were deleted.
- `BaseAdmissionBrowserBinding#ensure_base_admission_browser_nonce!` issues a fresh browser nonce on
  every initiation instead of adopting one already present in the session.
- `Base::App::Social::Authentication::CompletionsController` no longer writes the pre-login browser
  nonce back after `log_in`, and a committed signup whose ceremony is not completed is refused
  instead of re-entering `log_in`.
- `BaseLocalAuthenticationCompletion#complete_local_login_response!` no longer writes the pre-login
  sign-in locator back after `log_in`.

Checks performed: `ruby -c` and RuboCop passed on the four changed files; no references to the
removed constant or methods remain in `app/`, `lib/` or `test/`. Not verified: any runtime behavior,
the Base self-RP flow that previously relied on the preserved OIDC RP keys, multi-tab sign-in, and
post-removal attack replay. `session[:authentication_pt_nonce] ||=` in `AuthenticationRedirects`
still reuses a pre-login value; it signs return targets and issues no credential, and was left in
place.
