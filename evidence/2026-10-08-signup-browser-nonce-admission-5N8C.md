# Signup browser nonce admission

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`.
Uncommitted implementation/test/doc changes affected these results.

The existing `SignOtpCeremony` compared `session_nonce` with the public Ticket ID; all four concrete
APP/COM Email/Telephone OTP controllers supplied that ID. HTTP admission was independently gated,
but the service's own session contract was insufficient. Four public service reproductions supplied
that public reference and consumed valid proof, failing the new refusal assertions (seed 30221).

The service now requires an actual nonempty valid-encoding String nonce whose digest matches its
typed original Ticket. Admission repeats after row lock/reload, so stale model snapshots cannot
admit a rotated nonce. Controllers read only their explicit APP/COM locator session; no host-based
selection or legacy public-ID fallback exists. Existing CSRF, phase, owner and candidate controls
remain unchanged. No raw nonce or code was added to persistence or diagnostic output.

Verification:

- Malformed/browser service file passed 4 runs / 252 assertions, seed 48851: public-ID refusal,
  typed/malformed/foreign nonce partitions, nonce rotation against a stale subject, malformed code
  partitions and unchanged Contact proof/failure state.
- Three service files passed 40 / 458, seed 42553, before the added rotation partitions.
- Seven-file service/four HTTP-controller matrix initially failed 36 setup cases, seed 53058,
  from absent sign-in/cleanup reference data. Explicit semantic reference setup was added to each
  affected HTTP test, not a global test-helper alteration. The following HTTP run had two COM
  Telephone cooldown-fixture failures (35 / 297, seed 9824). Real issuance now records last-send
  time, so those tests had attempted their intended successful resend before the thirty-second
  cooldown ended. Their clock now advances to that exact boundary; the immediate next request
  still must enqueue nothing and return Too Many Requests.
- Final command: `bin/rails test test/services/sign_otp_ceremony_test.rb
  test/services/sign_otp_ceremony_lock_deadline_test.rb test/services/sign_otp_ceremony_malformed_code_test.rb
  test/controllers/auth/app/sign/up/check/email/otps_controller_test.rb
  test/controllers/auth/com/sign/up/check/email/otps_controller_test.rb
  test/controllers/auth/app/sign/up/check/telephone/otps_controller_test.rb
  test/controllers/auth/com/sign/up/check/telephone/otps_controller_test.rb`:
  **75 runs / 823 assertions, zero failures/errors/skips**, seed 35850, 16 processes.
- RuboCop passed the service, four production controllers and three service files (eight files),
  then the four HTTP fixtures and malformed-input file (five), and the final changed COM Telephone
  clock fixture (one). No offenses remained in those checks.

ADR and signup challenge diagram/inventory now describe actual nonce admission. Signup proof is
still Source-owned HOTP/context and its ownership migration remains incomplete. Full Rails/lint,
other OTP caller migrations and final invariant gates are not certified by these focused results.
No schema, secret, production or remote mutation occurred in this slice.
