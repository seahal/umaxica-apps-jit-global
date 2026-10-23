# WU-31: Email Sign-In OTP retained result (`already_verified`) — test results

- Date: 2026-10-23. Base commit `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`; change uncommitted (tests only).
- Decision: D-89 (tests first; reconciliation decided by the owner afterwards).

## Cases and results (APP and COM, `test/controllers/auth/{app,com}/in/emails_controller_test.rb`)

| D-89 case | Test | APP | COM |
|---|---|---|---|
| 1. Second `update` in the same ceremony with a different code after success | "a second update in the same ceremony with a different code after success records no second evidence" | Passed: not accepted, flow state and `updated_at` unchanged | Passed |
| 2. Same code from another independently admitted ceremony | "a code issued to one admitted ceremony is refused when submitted from another ceremony" | Passed: redirected back to `/sign/in/email/new`, other flow not advanced | Passed |
| 3. Repeat of the correct code (sequential form) | "resubmitting the same correct code after success records no second authentication event" | Passed: principal and `authentication_event_at` unchanged, not accepted again | Passed |
| 3. Two concurrent submissions on separate connections | — | **Not run**: no two-connection request harness for this endpoint yet | Not run |

Full files: 77 runs, 0 failures, 0 errors.

## Observation

The static concern (T23) does not reproduce through the endpoint: after the first success the flow
leaves `PRIMARY_PENDING`, so the sign-in flow binding no longer admits the email `update`, and the
`already_verified` branch of `AuthEmailOtpChallenge#verify_email_otp!` is not reached by these
paths. The branch still exists in the model; whether to remove it is the owner's reconciliation
decision (D-89).
