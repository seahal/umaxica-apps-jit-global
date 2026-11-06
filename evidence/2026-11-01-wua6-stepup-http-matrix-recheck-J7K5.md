# WU-A6 Standby operation recheck

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree already contained extensive uncommitted changes. This slice adds no application
  behavior.
- A focused Standby selection covered the fixture-free enforcement, IAM, telephone, contacts and
  Base bootstrap cases; Avatar transfer; birthdate; Secret edit/remove; Passkey
  detail/rename/remove; session revocation; the Action Policy context inventory; and
  `AuthenticationContextValue`.
- After disabling unneeded fixtures in the pure-value `AuthenticationContextValueTest`, the selected
  command finished with 28 runs, 4,885 assertions, 0 failures, 1 error, and 0 skips. All selected
  tests except the Standby support-session revocation test reached their assertions. That test
  stopped during fixture setup: `bureau_ownerships.operator_id` referenced `980190972`, which was
  absent from `operators`. This does not establish a product-code failure or a successful current
  run of that endpoint. A previous focused run of the support revocation flow is recorded in
  `evidence/2026-10-31-wua6-support-standby-operation-Y4K7.md`.
- A broader initial selection also included the legacy Auth Emergency controller test and ended with
  22 setup errors. The Auth test explicitly loads the affected shared fixtures; it was excluded from
  the narrowed rerun. No database rebuild or fixture data repair was performed.
- Targeted RuboCop for `test/values/authentication_context_value_test.rb`, Ruby syntax, and scoped
  `git diff --check` passed. No full suite was run. AC-41's complete per-operation Normal/Standby
  matrix and end-to-end Standby Root issuance remain open.
- The Auth Emergency controller test's stale comment that called the context `emergency` was
  corrected to say that it records Auth-side `standby` evidence; it now points readers to the
  guide's Visa issuance limitation. Ruby syntax and scoped `git diff --check` passed after that
  comment change; no behavior changed.
