# WU-A3 coupled status state local cutover

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this evidence file was added, the worktree
had 196 unstaged tracked files and 60 untracked files, with no staged changes. The existing worktree
was preserved.

The owner approved both status shapes and local development/test migrations. The cutover was limited
to local App and Org OP Base databases. No production or Neon database was accessed. Pre-migration
snapshots are in `/tmp/wua3-coupled-state-final-20261101T035605Z/`:

- Development App: `67f2a22d4fdbdcc4d25ae21dc21a61f3ee7c3b40c0c94e558cbbdef7c25c46a1`
- Development Org: `0120ce1a2ddc839c347554472c17a00200ff2697b20007ffa7b7191d21c0ef47`
- Test App: `e9d3fef54f74c575b283d4ad26fec31861910806c4a06dbd2609fae42fc827f7`
- Test Org: `6bb46292adffce96152f392d39d8cd18458ce120522be5ed13305bd3a638e72f`

Applied Admission Binding, Auth Ceremony, and OIDC parent status migrations to all four local
databases. Their states are represented by NOT NULL `status_id` columns and realm-local reference
tables. Auth Ceremony states are `issued`, `admitted`, `evidence_recorded`, `replaced`, `revoked`,
`completed`, `cancelled_before_progress`, and `cancelled_after_progress`. Admission Binding states
are `issued`, `attached`, `base_confirmed`, `redeemed`, `retired`, and `switched`. OIDC parent
states are `pending`, `authenticated`, `consumed`, and `canceled`; the former OIDC text `status`
column has been removed. Status-fact checks and foreign keys are validated in each database.

The pre-migration inventory was zero rows in Development App/Org and Test App, plus 16 Auth Ceremony
rows in Test Org; OIDC parents and Admission Bindings had zero rows in all four databases. The Test
Org rows were backfilled as 11 `revoked` and 5 `admitted`. Development databases still have zero
rows on these axes. After targeted tests, Test App has four `replaced` Auth Ceremony rows; they were
created by the tests and were left intact. Test Org retains its 16 backfilled rows.

The local test schema dumps were regenerated for `db/op_base_app_structure.sql` and
`db/op_base_org_structure.sql`. A scoped comparison of both OP Base test database schema dumps
matched the tracked files. The global schema-drift task was not used as an acceptance result because
it stops on the existing HMAC definer-role mismatch for `test_app_zenith_db` before completing the
comparison.

Verification after the current code and formatting changes:

- 18 focused Auth Ceremony, Admission Binding, OIDC, Visa, and sign-in flow test files: 181 runs,
  2,839 assertions, 0 failures, 0 errors, 0 skips.
- Targeted RuboCop on 50 affected models, concerns, migrations, and tests: no offenses.
- `git diff --check`: passed.
- Read-only checks against Development and Test App/Org confirmed NOT NULL `status_id`, populated
  reference tables (8 Ceremony, 6 Binding, 4 OIDC states per realm), validated status constraints,
  and absence of the OIDC text `status` column.

The initial test invocation without the repository's local container environment file stopped at
Rails initialization because the required `preference_com` issuer was absent. The same test command
passed after loading `.env.container.devcontainer`, which the README identifies as the local
container configuration source.

No full test suite was run. This record covers the approved local state-shape cutover and its
focused verification; it does not close all of WU-A3 or `two.md`.

## Follow-up invariant guard

HEAD remained `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree was uncommitted and had 490
status entries when this follow-up was recorded; no code was edited while the guard ran.

Ran `bin/rails test test/security/invariants/lifecycle_direct_state_write_invariant_test.rb` after
the owner-approved local cutover: 2 runs, 4 assertions, 0 failures, 0 errors, 0 skips. This checks
the static prohibition on direct lifecycle-state writes; it does not close the remaining WU-A3
acceptance matrix or replace the focused state-transition tests above.
