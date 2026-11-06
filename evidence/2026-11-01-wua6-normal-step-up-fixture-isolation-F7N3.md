# WU-A6 Normal ORG Step-Up test fixture isolation

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree contained existing staged, unstaged and untracked changes. This slice changed the
  fixture declaration in `test/integration/org_step_up_verification_enforcer_test.rb`, added a
  policy-boundary case in `test/unit/security/authentication_context_operation_inventory_test.rb`,
  and updated `four.md` and `docs/security/org-emergency-access.md`; no production code or schema
  changed.
- The test class creates its Operator and Step-Up records directly and does not read the five
  previously loaded fixture tables. Loading those shared fixtures failed before test assertions on
  `enterprise_units.enterprise_id`; the class now disables fixture loading.
- The focused real-passkey case passed: 1 run, 21 assertions, 0 failures, 0 errors, 0 skips.
- The complete affected test file passed: 5 runs, 35 assertions, 0 failures, 0 errors, 0 skips. The
  real-flow case verifies Auth WebAuthn, Base result consumption, Step-Up freshness resolution, and
  access to the protected Passkey page. It does not submit a protected mutation after Step-Up.
- `bundle exec rubocop test/integration/org_step_up_verification_enforcer_test.rb`, `ruby -c`, and
  `git diff --check` passed.
- The policy-only AC-41 case for `PublishingEntryPolicy#create?` passed: 1 run, 3 assertions. It
  observes that an active Operator is permitted under Normal and Standby claims and denied for an
  unknown context. The Operator is unsaved and the test does not issue an HTTP CMS write.
- The complete `test/unit/security/authentication_context_operation_inventory_test.rb` passed: 4
  runs, 4,586 assertions, 0 failures, 0 errors, 0 skips. This broad policy-rule comparison uses no
  actor/record; the separate publishing case is the only actor-specific write-policy check.
- The separate Normal Root continuation recheck and current 400 at the later Base-to-Auth binding
  confirmation remain recorded in
  `evidence/2026-11-01-wua6-policy-inventory-and-transaction-counts-U6M9.md`. Standby Root issuance
  and the full AC-41 operation matrix remain unverified. The full suite was not run.
