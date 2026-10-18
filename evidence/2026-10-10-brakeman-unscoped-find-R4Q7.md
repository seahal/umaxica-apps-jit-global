# Brakeman unscoped-find remediation

Date: 2026-10-10
Commit under test: `2a1644f73238839ed7ed513bd4681ea393a86682`
Worktree: `feature`, with pre-existing uncommitted changes and the current
`app/operations/identity_social_ceremony_final_committer.rb` change present.

## Change

The committed social-signup retry lookup now builds an explicit relation filtered by
`pending_contact_id`, `principal_id`, and provider, then uses `sole`. This preserves the ownership
predicate and raises on both missing and contradictory duplicate state without using the Brakeman
`find_by!` pattern that reported the weak `Unscoped Find` warning.

## Verification

`bin/brakeman -A` completed with Brakeman 8.1.0, 86 checks, 0 errors, and 0 security warnings
(`No warnings found`). `bundle exec brakeman -A` produced the same zero-warning result.

`ruby -c app/operations/identity_social_ceremony_final_committer.rb` returned `Syntax OK`, and
`git diff --check -- app/operations/identity_social_ceremony_final_committer.rb` was clean.

The focused service test completed with `14 runs, 73 assertions, 0 failures, 0 errors, 0 skips`.
The existing committed-social-signup retry integration test completed with `1 run, 42 assertions,
0 failures, 0 errors, 0 skips`, and the identity authority security guard completed with `8 runs,
101 assertions, 0 failures, 0 errors, 0 skips`.

An initial sandboxed Rails test attempt could not start because PostgreSQL host `primary` was not
resolvable; the successful rerun used the managed database network.
