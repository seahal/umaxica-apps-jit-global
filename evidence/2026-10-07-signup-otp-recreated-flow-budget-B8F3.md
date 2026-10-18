# Signup OTP recreated-flow failure budget

- Checkout: `6fa6867d44b5499632079775cb0fb22cbfddd339`; inherited and task-related uncommitted changes affect the checkout.
- Command: `bin/rails test test/services/sign_otp_ceremony_test.rb -i /failure_budget_survives/` against the isolated `codex_integrity_20261006fresh1_*` test fleet, PostgreSQL 17.7.
- Result: four runs / 32 assertions / four failures / zero errors or skips; seed 16742.
- Each app/com email/telephone case creates independent real candidate owners and flows at one destination. Five wrong real HOTP codes lock the first candidate. A correct HOTP for the second candidate succeeds, contrary to D-87's common failure budget across recreated flows and browser changes. No domain behavior or crypto is mocked.
- This exposes an existing implementation gap. The new test remains red; no test was removed, skipped or relaxed. No common budget implementation, schema migration or production/shared data change was made in this increment.
- The existing per-candidate OTP attempt counter and registration address/IP throttles do not establish the required common failure budget. A concrete expiring Valkey counter shape was presented for explicit approval required by `generic/data-shape-design.mdc`; that approval remains pending.
- This is not a measurement of real/dummy HTTP or timing parity and does not close Tasks 19.3, 19.4 or Final Verification.
