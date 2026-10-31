# Auth email OTP cooldown ordering review

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the reviewed implementation.
- Read-only inspection compared `two.md` sections 5.1 and 12.2, `app/controllers/auth/app/sign/in/emails_controller.rb`, `app/models/concerns/auth_email_otp_challenge.rb`, `adr/email-otp-race-condition-fixes.md`, and the cooldown case in `test/controllers/auth/app/in/emails_controller_test.rb`.
- The app sign-in controller currently stores the existing-email session state and issues an OTP generation before checking the contact's source cooldown. The existing controller test expects the first cooldown refusal to leave that newly issued challenge in place. This differs from the proposed rule that a cooldown refusal must leave the generation and progress unchanged.
- The accepted race-condition ADR requires rechecking cooldown under the relevant lock; moving the existing unlocked controller check before issuance alone would not satisfy that requirement. The OTP concern currently takes parent and ceremony locks before its contact-owner lock, whereas `two.md` section 12.2 specifies owner before OP locks. Both need to be addressed together, including real/dummy response parity and issuance/dispatch failure tests.
- No implementation change or test execution was made in this review. This record does not establish that the full OTP work unit is complete.
