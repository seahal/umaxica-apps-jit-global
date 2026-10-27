# D-198: APP social sign-path refusals follow D-47

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; dirty worktree with extensive uncommitted cycle
  changes.
- Change: `SocialAuth#handle_social_auth_error` and `#handle_record_not_unique` call
  `refuse_sign_in_path!` for every intent except `link` (reason from `social_sign_path_refusal_reason`:
  `intent_crossing`, `ownership_mismatch`, `subject_enforced`, `credential_failed`, `state_expired`,
  `state_invalid`, `provider_failed`; `phase_violation` for the unique-index guard). The APP OmniAuth
  failure endpoint ends a sign-path attempt (`state_invalid` for `csrf_detected`, else
  `provider_failed`). `AppSocialCeremonyEntry#prepare_surface_ceremony_state!` refuses a second
  sign-up social start for an admission that already has a Sign-up Flow (`phase_violation`) before
  storing intent or inserting. Settings linking (`link`) keeps its redirect.
- Red first: `test/integration/social_login_admission_test.rb` with two new D-198 tests and the
  L2 expectation changed to the uniform 400: 11 runs, 3 failures before the change.
- Green: the same file 11 runs, 234 assertions, 0 failures;
  `test/integration/social_callback_refusal_matrix_test.rb` (refusal expectation changed from 302 to
  400; success, 403 and 500 cells unchanged) 1 run, 1,160 assertions, 0 failures.
- Comparison over 237 APP social/OmniAuth test files (`PARALLEL_WORKERS=4`): with the change 2,087
  runs, 38 failures, 88 errors; with the change temporarily removed 41 failures, 88 errors. Only-before
  failures were the four new/changed D-198 expectations; the one only-after failure was the matrix
  test, then updated as above. Remaining failures are pre-existing (`NoMethodError` on `nil`,
  `AppSecretLoginJourneyTest`, and others) and were not investigated.
- ORG OmniAuth and APP settings Google/Apple tests: 50 runs, 1 failure
  (`OrgSocialLoginBlockedTest` sign-in page now redirects to Visa confirmation; ORG code was not
  changed). RuboCop: no offenses on the five changed files. No browser check yet.
