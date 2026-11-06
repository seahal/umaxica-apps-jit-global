# WU-A6 ORG Email and Telephone registration checks

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. At verification the worktree contained 558
modified tracked paths and 275 untracked paths; the index was clean. Existing work was preserved and
no commit was created.

The Email and Telephone registration controller test classes no longer load shared global fixtures.
They create explicit active Operators and Passkeys; the Telephone tests also create a separate
Operator for foreign-owner cases. Passkey reads use the owning model query, avoiding strict-loading
association access. No application code or schema changed.

Before this change, the two selected Normal registration cases failed in fixture setup with an
`enterprise_units.enterprise_id` foreign-key violation, before any assertions. After fixture
isolation, the selected successful registration cases passed together: 2 runs, 23 assertions, 0
failures, 0 errors, 0 skips. The existing ORG Standby Email-entry refusal passed (1 run, 12
assertions), and the new ORG Standby Telephone-entry refusal passed (1 run, 12 assertions); both
Standby paths refuse the form GET and registration POST without creating protected rows or a Step-Up
transaction.

The combined Email and Telephone controller files passed on two consecutive follow-up runs, each
with 52 runs, 357 assertions, 0 failures, 0 errors, 0 skips (the second run used seed `44800`). An
earlier full-file run reported 1 failure at 52 runs / 355 assertions. Its detail was truncated from
the captured output and could not be identified; the same file set and seed then passed. This
unresolved first-run discrepancy is retained rather than treated as a verified pass.

Scoped RuboCop reported no offenses in the two controller test files; Ruby syntax checks and
`git diff --check` passed. These cases pair Normal Step-Up registration success with Standby
registration refusal for Email and Telephone. The wider AC-41 operation matrix and actual Standby
Root issuance remain open. No full test suite was run.
