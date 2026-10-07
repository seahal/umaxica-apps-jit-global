# Shared OTP signup verification budget

Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`. The worktree contains inherited and current uncommitted changes affecting the result.

The owner approved an integer failure count keyed by surface, purpose, channel and the existing
normalized destination digest, with five failures and a fixed 15-minute first-failure deadline.
Candidate/flow/browser/owner are not key components. The accepted same-scope third-party exhaustion
risk is bounded by the original deadline; purpose separation prevents signup from exhausting other
purposes. Existing candidate locks remain.

- The four public signup recreated-candidate/flow/browser regressions were red before integration
  (4 runs, 32 assertions, 4 failures; seed 16742, earlier takeover run).
- New adapter tests initially errored because the adapter did not exist (3 runs, 3 NameErrors;
  seed 24934). After implementation, its first three tests passed (3 runs, 30 assertions; seed 21974).
- `bin/rails test test/adapters/otp_verification_budget_adapter_test.rb test/services/sign_otp_ceremony_test.rb`
  passed after concurrency implementation and formatting: 27 runs, 215 assertions, no failures,
  errors or skips (seed 43619), using the owned `codex_integrity_20261006fresh1` test fleet and
  namespaced real auth-state Valkey.
- Coverage includes four/five/six failures, successful verification without reset, exact retained
  native deadline, independent scopes, corrupt/persistent counters, dependency outage, concurrent
  failure capping and native expiry. Expiry's one-ms round-trip observation limitation is recorded
  in the test; no caller clock controls production expiry.

Only app/com signup email/telephone is integrated in this increment. Sign-in, authenticated
destination confirmation, complete dispatch/parity verification and Final Verification are not
certified. No Task checkbox was completed on the strength of this partial slice.
