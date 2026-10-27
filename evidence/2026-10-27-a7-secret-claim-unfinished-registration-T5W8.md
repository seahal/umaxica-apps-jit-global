# A-7: Secret sign-in leaves an unfinished registration's credential unclaimed (D-194 (1))

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; dirty worktree with extensive uncommitted cycle
  changes.
- Cause: `ClientSecretClaimCommitter` decided eligibility with `Client#login_allowed?`, which admits a
  `UNVERIFIED_WITH_SIGN_UP` principal; `sign_in_allowed?` (D-106) excludes it. The Flow binding and the
  irreversible `claimed_at` were committed before `AuthenticationSessionCommitter` refused.
- Fix: both checks in `ClientSecretClaimCommitter` (`call!` and `oidc_binding_admitted?`) use
  `sign_in_allowed?`, so neither the Flow binding nor the claim is written.
- Test: `test/controllers/auth/app/in/secrets_controller_test.rb` A34-2. With the old check it fails
  at line 134 (`claimed_at` set). Its final assertion read the transaction through a strict-loading
  association and raised `StrictLoadingViolationError`; it now loads
  `ClientOidcAuthorizationTransaction` by id (test defect, same assertion).
  With the fix: file 16 runs, 136 assertions, 0 failures, 0 errors; with the old check the A34-2 case
  fails (1 run, 1 failure).
- Wider Secret set (`rg -l 'ClientSecretClaimCommitter|sign/in/secret|sign_in_secret' test`): 133 runs,
  same failing test locations with and without the fix (pre-existing, e.g.
  `AppSecretParallelLoginTest` `NoMethodError` on `nil`).
- Same pattern elsewhere (reported, not fixed):
  - APP Email OTP sign-in (`Auth::App::Sign::InsController` path,
    `app/controllers/auth/app/sign/in/emails_controller.rb:358`) issues an OTP when
    `login_allowed?`, so an unfinished registration gets an OTP challenge before the later refusal.
  - Passkey sign-in (`PasskeySignInFlow#passkey_eligible_for_sign_in?`) checks `actor.active?` and
    updates `sign_count`/`last_used_at` before `perform_passkey_sign_in` refuses.
- RuboCop: no offenses on the two changed files.

## Follow-up (owner asked to fix the two reported paths)

- APP Email OTP sign-in (`app/controllers/auth/app/sign/in/emails_controller.rb`) and the shared
  `PasskeySignInFlow#passkey_eligible_for_sign_in?` now use `sign_in_allowed?`. An unfinished
  registration is answered like an unknown address (only the fake OTP context, no contact named) and a
  Passkey assertion is refused before `sign_count`/`last_used_at` are written.
- Red first: new APP email test and the strengthened APP Passkey A34-2 test failed with the old
  checks (3 runs, 2 failures) and pass with the fix. The Passkey refusal is now the generic
  verification failure 401 instead of 422 on APP and COM (shared concern); both A34-2 tests were
  updated to that status (A34-2 requires a refusal with no token or cookie, not a status).
- 43 files touching Passkey/email sign-in (`PARALLEL_WORKERS=4`): with the fix 4 failures, 58 errors;
  without it 5 failures, 59 errors. Only-after: the COM A34-2 status (updated) and
  `SignUpPasskeyTerminationHttpTest:383`, which passed when run serially with the COM file
  (27 runs, 0 failures). RuboCop: no offenses on the five changed files.
