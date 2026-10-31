# APP signup OTP unknown results

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted application and test changes.
- Injecting an unregistered verification result at the public Email and Telephone OTP endpoints previously produced ordinary invalid-code responses instead of raising (2 tests, 2 failures). The controllers now explicitly enumerate their currently known issuance/verification outcomes and raise `ArgumentError` for an unsupported outcome.
- Four public-request cases cover injected unknown resend and verification outcomes on both channels (4 runs, 8 assertions). The Email and Telephone signup controller and issuer files passed together (147 runs, 1,510 assertions), with scoped RuboCop and `git diff --check` passing.
- The unknown results were injected. This change preserves existing responses for recognized outcomes and does not implement the complete `two.md` §6.6 status table: recognized state/binding mismatches still follow current controller behavior, which needs separate response-shape review. No real provider or outage was exercised.
