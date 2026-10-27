# ORG authority-stop realm length: partial batch 1

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`. The worktree had extensive uncommitted cycle changes, including the changes measured here.
- Before the change, `bin/rails test test/models/string_column_length_validation_contract_test.rb -n /OpOrgAuthorityStop/` reported 2 runs, 24 assertions, 1 failure and 0 errors: `OpOrgAuthorityStop#realm` did not reject four characters in the length validator.
- After adding the three-character maximum, the same test with `-i /OpOrgAuthorityStop/` reported 2 runs, 32 assertions, 0 failures and 0 errors. The generic guard also exercises the related ORG stop model.
- `bundle exec rubocop app/models/op_org_authority_stop.rb`: 1 file inspected, no offenses.
- `bin/rails test test/services/oidc_token_revocation_service_coverage_test.rb`: 7 runs, 15 assertions, 0 failures and 2 errors, both missing `actor_record` on the test token. The current committer also requires a real grant class, so the fake requires further investigation.
- The two positive revocation cases now use real APP grants. The same test file then reported 7 runs, 23 assertions, 0 failures and 0 errors. RuboCop autocorrected formatting in that file; the test was run before the formatting-only correction.
- A batch-1 diagnostic run of eight test files reported 66 runs, 549 assertions, 7 failures and 2 errors. A narrower six-file run reported 21 runs, 187 assertions, 4 failures and 1 error. The controller inheritance guard reports six Visa logout controllers inheriting from other controllers. This is an implementation violation rather than a stale removed-controller entry; fixing it requires production changes outside the permitted realm validation, or a reviewed change to the guard's contract. No guard exception was added.
- COM was excluded from this work. Batch 1, later batches, and the full suite remain incomplete; no comparison with the full-suite baseline has been made.
