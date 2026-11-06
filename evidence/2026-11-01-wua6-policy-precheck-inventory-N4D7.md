# WU-A6 policy pre-check operation inventory

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 584 staged, unstaged, or
  untracked status entries at verification; no commit was created.
- `test/unit/security/authentication_context_operation_inventory_test.rb` previously called
  `AuthenticationContextValue#permits_rule?` directly, so it did not execute `ApplicationPolicy`'s
  real Action Policy pre-check. Its method inventory also included inherited `Object` predicates
  such as `equal?` and `instance_of?`.
- The test now inventories zero-argument predicate methods declared in each policy's
  `ApplicationPolicy` ancestry and calls `policy.apply(rule)` under installed Normal, Standby, and
  unknown token claims. For the policy application it uses a nil actor/record except for the
  concrete authentication access context; it checks pre-check parity/fail-closed behavior, not real
  actor permissions or public HTTP operations. Existing focused HTTP cases remain necessary for
  those boundaries.
- The first focused run failed before assertions because unrelated global fixtures violated the
  `bureau_ownerships.operator_id` foreign key. This inventory needs no database fixtures, so the
  test class now disables fixture loading.

## Verification

- Initial focused run: 3 errors, 0 assertions; fixture setup failed before test bodies.
- Final
  `PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS= bin/rails test test/unit/security/authentication_context_operation_inventory_test.rb`
  — 3 runs, 4,583 assertions, 0 failures, 0 errors, 0 skips.
- `bundle exec rubocop test/unit/security/authentication_context_operation_inventory_test.rb` — 1
  file inspected, no offenses.
- `ruby -c test/unit/security/authentication_context_operation_inventory_test.rb` — Syntax OK.
- `git diff --check -- test/unit/security/authentication_context_operation_inventory_test.rb` —
  passed.
- Updated `docs/security/org-emergency-access.md` to describe this narrower policy-layer guarantee
  and retain the open HTTP-operation matrix; `git diff --check` passed for the documentation update.

No application code, schema, migration, or persistent data was changed. This improves the
policy-layer AC-41 check but does not close the full Normal/Standby operation matrix or establish
actual Standby Root issuance. The full suite was not run.
