# WU-A4 Source cooldown non-disclosure

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before adding this record, the worktree had 511
modified or untracked paths and no staged changes. Existing work was preserved.

The prior APP sign-in Source-cooldown behavior returned HTTP 429 for an eligible registered contact
while an unknown address followed the dummy continuation and returned HTTP 302. A focused regression
test reproduced the difference (1 run, 5 assertions, 1 failure: registered 429 versus unknown 302).

`Auth::App::Sign::In::EmailsController` now follows the existing dummy challenge path when the
locked Source Contact reports cooldown. It does not send mail or update the Source Contact; the user
receives the same initial continuation as an unknown address. The controller test now checks initial
response equality, the dummy session, preservation of the Source timestamp, and no queued email. The
existing repeat-request cooldown test still verifies that the common address limiter returns the
same 429 without rotating the challenge.

Focused checks with `.env.container.devcontainer` loaded:

- `bin/rails test test/controllers/auth/app/in/emails_controller_test.rb:655 test/controllers/auth/app/in/emails_controller_test.rb:695`:
  2 runs, 26 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test test/controllers/auth/app/in/emails_controller_test.rb test/controllers/auth/app/in/emails_controller_enumeration_test.rb`:
  57 runs, 590 assertions, 0 failures, 2 errors, 0 skips. Both errors are the existing
  baseline-listed `EmailsControllerEnumerationTest` cases
  (`test_the_cooldown_response_is_identical_for_registered_and_unregistered_addresses` and
  `test_a_failed_Turnstile_request_does_not_reserve_the_address-wide_bucket`); both fail at
  `response.parsed_body.at_css` because the value is a String. No other error appeared.
- Targeted RuboCop on the controller and changed controller test: no offenses. `ruby -c` passed for
  both; scoped `git diff --check` passed.

The focused behavior change is verified. The two baseline-listed enumeration test errors remain
unresolved; no full suite was run.
