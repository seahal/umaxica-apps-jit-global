# Frame-denying CSP keeps the application policy

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; the worktree had extensive uncommitted cycle
  changes, including the A12-5 change this record builds on
  (`evidence/2026-10-27-a12-5-visa-confirmation-frame-D4K8.md`).
- Defect: six places wrote `Content-Security-Policy` by hand (`frame-ancestors 'none'`, two with
  `form-action 'self'`). `ActionDispatch::ContentSecurityPolicy::Middleware#call` returns early when
  the header is present (actionpack `http/content_security_policy.rb:44`), so those responses carried
  no `default-src`, `script-src` or `object-src`.
- Change: new `FrameDenyingContentSecurityPolicy#deny_framing!` clones
  `request.content_security_policy`, sets `frame_ancestors(:none)` (and `form_action(:self)` for the
  social link completion) and assigns it back. Used by `AuthCeremonyAdmission`,
  `BaseAdmissionBrowserBinding`, `AuthOidcResultHandoff`, `SocialAuth` and
  `Auth::App::Social::LinkCompletionsController`. The redundant header write added to
  `BaseCeremonyBindingConfirmation#refused_confirmation_destination?` was removed (the confirmation
  already gets the header from `apply_base_browser_continuation_headers!`).
- Test: `acceptance_wu12_relay_repeat_test.rb` previously asserted the header equals
  `frame-ancestors 'none'` (passing before the change, i.e. the defect was asserted). It now asserts
  `frame-ancestors 'none'` plus `default-src 'self'`, `object-src 'none'` and
  `script-src 'self' 'strict-dynamic'`.
- `PARALLEL_WORKERS=1 bin/rails test` on `acceptance_wu12_relay_repeat_test.rb`,
  `visa_authorization_continuations_test.rb`, `security_headers_test.rb`,
  `ceremony_admission_boundary_test.rb`, `social_login_admission_test.rb`,
  `social_callback_refusal_matrix_test.rb`, `sign_up_passkey_termination_http_test.rb`: 70 runs,
  3,052 assertions, 0 failures, 0 errors.
- Broad run of 282 test files matching the affected paths (`PARALLEL_WORKERS=4`): 3,062 runs,
  116 failures, 241 errors. The same failing files run with the old header lines temporarily put back
  gave 114 failures, 236 errors; no test failed only before. Nine tests failed only after; each passed
  when the files were run serially with the change (above), so they are treated as parallel-order
  flakiness, not regressions. The remaining failures (mostly `NoMethodError` on `nil` in social and
  route-guard tests) are pre-existing and were not investigated.
- `bundle exec rubocop` on the 8 changed files: no offenses. Actual browser behavior was not checked.
