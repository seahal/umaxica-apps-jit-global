# Auth Email OTP input and isolated fixtures

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`. Uncommitted worktree changes affected these
results. Verification used only the ordinary local Rails test databases.

The Auth challenge/deadline/mailer matrix initially completed 62 runs with 30 errors, seed 46129.
Deadline and mailer fixtures omitted their required sign-in state records, producing foreign-key
errors on isolated parallel workers. Explicit setup now creates the existing semantic state values
inside each test transaction, rather than depending on another file's setup. The unchanged behavior
matrix then passed 62 runs and 290 assertions, seed 22271, with 16 processes.

Extending the malformed-code partition with NUL, full-width digits and invalid UTF-8 reproduced two
errors in the public Auth verifier, seed 64951. Regex matching raised before returning the documented
invalid-code result. The channel-owned format predicate now checks encoding before matching; no
exception swallowing or substitute code was added. The matrix passed 62 runs and 296 assertions,
seed 62996, without failures, errors or skips. After extracting the pure format predicate to preserve
the complexity gate, the focused cases passed two runs and 52 assertions, seed 5455.

RuboCop passed for the four modified Auth concern/model-test/deadline-test/mailer-test files. These
results do not certify removal of Source HOTP storage or completion of the remaining transport flows.
