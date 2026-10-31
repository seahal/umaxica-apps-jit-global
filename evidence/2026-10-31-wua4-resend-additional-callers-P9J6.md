# Additional sign-in resend callers

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting this check.

Searching other callers and running `PARALLEL_WORKERS=1 bin/rails test test/integration/sign_entry_otp_admitted_order_test.rb test/integration/email_sign_in_enumeration_parity_test.rb test/controllers/auth/app/in/emails_controller_test.rb` exposed four further failures (64 runs, 701 assertions): each expected a successful resend inside a fixture transaction and received the new service-unavailable response.

Two admission-order cases and the real/dummy parity case now run their own transaction boundaries and clean up their synthetic data. The parity case then exposed an additional local writer/replica mismatch on the clean Auth sign-in page: the just-committed authorization parent and admission binding were read on the request role. Their context lookups now use the appropriate OP writer. The local test replicas are separate databases; deployed replica behavior was not measured.

`PARALLEL_WORKERS=1 bin/rails test test/integration/sign_entry_otp_admitted_order_test.rb test/integration/email_sign_in_enumeration_parity_test.rb test/concurrency/sign_in_otp_resend_serialization_test.rb` passed: 17 runs, 192 assertions. The targeted parity case passed with 55 assertions. Scoped RuboCop reported existing offenses in the parity file as well as offenses corrected in the touched lines; it was not rerun after those corrections. The controller file's queue-refusal/resend test still needs to be changed to use committed Auth and occurrence transactions. Other admission readers, ORG clean-entry behavior, real delivery and the full suite remain unverified.

After ensuring that collision checks precede assignment of rows eligible for test cleanup, the three modified cases passed together: 3 runs, 76 assertions.
