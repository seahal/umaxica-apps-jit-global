# WU-A4 XDB-02 Passkey name final Zenith commit boundary

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 522 status entries, including
this change; no staged changes were present. No commit was made.

The existing XDB-02 Ticket-consumption-before-Zenith-failure case passed on both APP and ORG (1 run,
10 assertions). Added an APP and an ORG case that injects failure at the final Zenith database
commit, after Ticket Step-Up consumption. Both cases confirm the old Passkey name remains, no
Passkey audit row is committed, and the Step-Up proof is spent.

Ran with `.env.container.devcontainer` loaded:

- The two new final-commit cases passed: 2 runs, 8 assertions, 0 failures, 0 errors, 0 skips.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/identity_passkey_name_committer_test.rb`
  passed: 13 runs, 92 assertions, 0 failures, 0 errors, 0 skips.
- `ruby -c`, RuboCop and scoped `git diff --check` passed for the changed test file.

This verifies the injected final-Zenith-commit failure outcome for APP and ORG. It does not close
the other XDB-02 races or establish an actual network partition after server-side commit.
