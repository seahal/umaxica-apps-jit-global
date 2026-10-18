# Cookie settings authority

Commit: `f8c93e4a9a50e22a942976a5810962f039662206`.
The worktree contained unrelated uncommitted changes and this fix.

Cookie settings already used a `_url` helper, but non-Auth chrome did not explicitly
select the Base authority host. The fix selects the public Base host for app, com,
and org while preserving Auth's existing authority selection.

- The initial sandboxed test could not connect to PostgreSQL at `primary`.
- The reproduction test outside the sandbox failed on the destination host assertion.
- After the fix, `bin/rails test test/integration/cookie_settings_authority_test.rb
  test/integration/sign/app/layout_test.rb` passed: 3 tests, 32 assertions.
- Ruby syntax checks passed for the changed concern and new test.
- `git diff --check` passed.

The regression covers Warp's three surface links, preference query propagation,
and exclusion of an empty unrelated `query` parameter. The reported deployed Palm
URL was not checked in a browser; no deployment was performed.
