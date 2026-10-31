# WU-A6 ORG Secret removal Normal and Standby

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting implementation and tests.
- The selected existing Normal and Emergency removal cases passed before this test change (3 runs, 13 assertions). The Emergency case previously only checked that the response was not the success redirect and the credential remained active.
- The Emergency case now also requires HTTP 403, confirms the credential stays active, the token stays Standby and no Step-Up freshness is issued. The selected Normal cases exercise removal while another sign-in method remains and observe the target leaving active state. The Normal setup writes synthetic freshness into the test token; it does not run an actual WebAuthn Step-Up ceremony.
- `PARALLEL_WORKERS=1 bin/rails test test/controllers/base/org/identity/removals_controller_test.rb:133 test/controllers/base/org/identity/removals_controller_test.rb:316 test/controllers/base/org/identity/removals_controller_test.rb:584` passed (3 runs, 16 assertions, 0 failures, 0 errors, 0 skips). No application implementation was changed.
- These cases cover one ORG Secret-removal boundary, not all AC-41 operations, the separate ORG Secret audit/transaction gaps, or a Standby Root login.
