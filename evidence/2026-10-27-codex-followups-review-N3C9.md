# Review of Codex's Z8R4 and H6Q3 work, and two product fixes

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; dirty worktree with the uncommitted cycle
  changes and Codex's test additions.
- A15-7 (Codex, production): `OutboundHttp::ConnectionAdapterPort` replaced the non-existent
  `IPAddr#exclude?` with `return true unless GLOBAL_IPV6_NETWORK.include?(address)`, then the blocked
  IPv6 list. Reviewed: minimal and correct; non-global IPv6 (private, loopback, link-local,
  IPv4-mapped) is refused.
- A44-10 product defect (reported by Codex): `AuthenticationOtherSessionsRevoker#call` enumerated the
  lazy `sessions` relation after waiting for the current-root lock, so a root committed during the wait
  was revoked (contrary to D-167, point-in-time). Red: new test in
  `test/operations/authentication_other_sessions_revoker_test.rb` ("a session created after the
  revocation request survives"; 1 run, 1 failure). Fix: enumerate `sessions.where(created_at: ..now)`,
  where `now` is the database time read before the lock. Green: the revoker test file plus the Base
  revoke-others controller tests, 90 runs, 1 failure (`identity_authority_inversion_guard_test.rb:42`,
  pre-existing route-source assertion, present in the full-suite runs). The concurrency test
  `root_revoke_others_concurrent_login_test.rb:84` was not repaired: its setup already fills
  `ClientToken::MAX_SESSIONS_PER_USER` (Codex's diagnosis).
- Secret method mismatch product defect (reported by Codex): `Visa::App::AuthorizationBaseController#login_for_oidc`
  raised `AuthenticationBase::SignInFlowIssuanceRejected` when a Secret flow's transaction named
  another method; the continuation did not rescue it (500). Red: new test in
  `test/integration/oidc_initiated_sign_in_completion_test.rb` ("a Secret flow whose transaction method
  is not passcode is refused without a Root"; 1 error). Fix: return `{ status: :login_failed }` like the
  other unusable-flow cases. Green: that file, Visa continuations and sign-entry exit flow, 26 runs,
  522 assertions, 0 failures.
- Codex correctly refused the instruction's expected logout form action (`/oidc/logout?ri=…`): the
  form posts to `/oidc/logout/confirmation` per `ten.md` §3.2; the instruction was wrong. Codex also
  found two unreachable branches, left as they are: the "authorization transaction is not ready"
  branch in each realm's authorization base (the continuation refuses earlier with the generic
  response) and the `sign_out_post_path` overrides in the Visa logout concerns (the form action comes
  from `SignOidcLogout#sign_out_confirmation_form_path`).
- RuboCop: no offenses on the changed production files; six pre-existing offenses in untouched helper
  lines of `oidc_initiated_sign_in_completion_test.rb`.
