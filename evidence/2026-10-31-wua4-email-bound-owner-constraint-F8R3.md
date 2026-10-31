# Effective Email owner constraint investigation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes affecting the tested code.
- Two temporary test cases attempted to reassign a finalized Client Email directly before Email Step-Up issuance or verification. Both errored at the reassignment: PostgreSQL rejected a change to the owner of an effective contact binding. The temporary cases were removed; no application change was made on the basis of this unreachable mutation.
- The migration `20261008025001_add_client_identifier_hmac_maintenance.rb` implements the constraint. The existing direct-write constraint test and the Email Step-Up issuer and verification files passed: `PARALLEL_WORKERS=1 bin/rails test test/models/contact_binding_constraints_test.rb test/operations/identity_step_up_email_verification_committer_test.rb test/operations/identity_step_up_email_code_issuer_test.rb` — 16 runs, 182 assertions, 0 failures, 0 errors, 0 skips.
- This does not prove concurrency of legitimate release, delivery and verification, or the state of any deployed database. The full suite was not run.
