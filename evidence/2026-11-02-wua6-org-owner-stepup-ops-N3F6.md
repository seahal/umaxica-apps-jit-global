# WU-A6 ORG owner-operations Step-Up fixture isolation

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this evidence file was added, the worktree
contained 556 modified tracked paths and 274 untracked paths; the index was clean. Existing changes
were preserved and no commit was created.

The four ORG owner-operation controller test classes now isolate global fixtures and create the
operators, second Passkeys, client, and client email records required by their cases. No production
code or database schema changed in this slice.

The focused command ran the revocation, session-revocation, enforcement-case, and IAM-grant test
files with one test worker and the required local COM issuer/audience configuration. Result: 51
runs, 244 assertions, 0 failures, 0 errors, 0 skips. Scoped RuboCop reported no offenses in the four
files. Ruby syntax checks passed for all four files, and `git diff --check` passed.

This covers selected Normal and Standby owner operations and related refusals. It does not establish
the complete policy-derived AC-41 HTTP matrix or actual Standby Root issuance. The full test suite
was not run, and WU-A6 remains open.

Follow-up `bin/rails test test/integration/org_root_login_establishment_test.rb` reproduced a
separate failure: 1 run, 56 assertions, 1 failure. The Auth → Base ceremony-binding confirmation GET
returned HTTP 400 where the test expected 200. The generic invalid-request response does not
identify which binding condition refused the request; that condition remains unisolated. No code was
changed during this follow-up.

The existing ORG Standby Email-registration case passed before the Telephone change (1 run, 12
assertions). A new matching Telephone-registration case was added to
`test/integration/base_passkey_mutation_step_up_test.rb`;
`bin/rails test test/integration/base_passkey_mutation_step_up_test.rb:400` passed (1 run, 12
assertions). Its GET and POST both returned 403, and the operator received no Step-Up transaction,
Telephone row, or Telephone ceremony transaction. Scoped RuboCop, Ruby syntax, and
`git diff --check` passed.

At this update the worktree contained 556 modified tracked paths and 275 untracked paths, with no
staged paths. No commit was created.

After adding the Telephone case, the full `test/integration/base_passkey_mutation_step_up_test.rb`
file passed: 5 runs, 157 assertions, 0 failures, 0 errors, 0 skips. Scoped RuboCop reported no
offenses and `git diff --check` passed. Updated `docs/security/org-emergency-access.md` to describe
this selected Standby refusal coverage and keep the full operation matrix open. HEAD remained
`efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; the worktree remained uncommitted.
