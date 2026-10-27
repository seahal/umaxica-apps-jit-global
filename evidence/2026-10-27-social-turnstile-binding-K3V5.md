# Social confirmation Turnstile binding

HEAD: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`. The worktree contained uncommitted changes affecting these checks.

- `PARALLEL_WORKERS=1 bin/rails test test/integration/social_login_admission_test.rb:271`: 1 run, 40 assertions, no failures, errors or skips. The Google confirmation request passed the token, action, request host and current Flow public ID to the verifier boundary and completed the existing registration journey.
- `PARALLEL_WORKERS=1 bin/rails test test/unit/jit/security/turnstile_verifier_test.rb:239`: 1 run, 6 assertions, no failures, errors or skips. Independently mismatching hostname, action and cdata were rejected.
- `bundle exec rubocop test/unit/jit/security/turnstile_verifier_test.rb --format simple`: no offenses. RuboCop on `test/integration/social_login_admission_test.rb` reported an existing empty-line offense at line 384, outside the added assertions.

An initial Google run at line 270 selected zero tests and is not counted as verification.

Subsequently, `PARALLEL_WORKERS=1 bin/rails test test/integration/apple_social_flows_test.rb:41` initially errored before reaching confirmation because its entry followed the old host sequence. After updating that entry, the test reached Apple confirmation and all six new verifier-argument assertions passed, but the overall run errored later in its legacy sign-in handoff (`response.parsed_body.at_css` on a String): 1 run, 31 assertions, 1 error. The Apple journey is not a passing check, so A05-12 remains partial. RuboCop on the file reports four line-length offenses outside the changed portion; `git diff --check` passed.

After updating the continuation to use the current Auth → Visa → Base callback and retaining the token/UserInfo controller transport, the same Apple test passed: 1 run, 41 assertions, no failures, errors or skips. This includes Apple confirmation binding and the RP callback. RuboCop still reports four pre-existing line-length offenses outside the changed portion.
