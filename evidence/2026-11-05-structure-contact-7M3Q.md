# Structure, operator cleanup and registered-contact verification

Date: 2026-11-05 UTC 15:36  
HEAD: `b30345216886c98af1f04cbd434f067f12decf01`  
Worktree: extensive uncommitted changes affected the schema and test results.

## Schema snapshots

Ran the development schema dump tasks for Chronicle, OP Base APP/ORG, RP Base APP/ORG and the
primary database. The resulting line counts are 3,380; 6,423; 5,249; 1,042; 967; and 413. Direct
temporary dump comparisons with `SchemaDriftVerification.dump_matches?` returned `true` for all six.
Against HEAD, the SQL diffs are respectively 20/19, 1,649/109, 1,534/139, 549/0, 474/0, and 0/0
added/removed lines. These are the current migration-derived catalog shapes; the OP/RP diffs include
the accepted O-9/O-10 and step-up tables/state, plus other current applied migration shapes.
`db:verify_no_schema_drift` also reports modified tracked schema files as drift while the worktree
is uncommitted, so it is not a clean-worktree verification result.

The truncating operation was `RAILS_ENV=test bin/rails db:migrate:reset:<database>` at 04:00 (26
writable logical test databases) and the explicit app_zenith/op_base_app reset tasks at 08:34. Rails
dumps the empty pre-migration database during `migrate:reset`, then migrates without a final dump,
leaving the 18-line header. The repository's `db:test:prepare` override migrates only and does not
write structure snapshots.

## Minitest operator residue

`RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test` completed with 17,016 runs, 141,363 assertions,
654 failures, 418 errors and 0 skips (997.942 seconds). The output contains no operator FK violation
and no reference to operator 980190963. A read-only post-run query found no operators, authority
locks or accounts for IDs 980190963, 980190984, 980190997, 980190092 or 980190093, and zero orphan
lock/account IDs. The original 980190963 row was already deleted, so its unique writer cannot be
proven. `SignOrgCredentialRemovalConstraintsTest` remains the strongest code-level candidate; its
nontransactional teardown now removes the actor ownership graph, account and lock before the
operator.

## Registered email/telephone behavior

The targeted verification command covered the NOT NULL validation contract, the complete sign-up OTP
delivery concurrency file, email and telephone sign-up HTTP delivery regressions, contact OTP
verification/finalization, both sign-up and post-login issuer operations, and response timing.
Result: 751 runs, 5,061 assertions, 0 failures, 0 errors, 0 skips. Scoped RuboCop inspected 31
relevant model/test files with no offenses. The full suite still does not provide end-to-end
evidence for Base APP post-login registration controller routes: the email controller setup raises
`BaseAuthAdmissionCoordinator::Denied` for a missing step-up requirement binding, and telephone
controller cases redirect before exercising registration. The sign-up incident reproductions for
both email and telephone pass.

The concurrency tests were monitoring OP database backend PIDs even though the protected row lock
was in APP's `clients` table. They now monitor the APP backend PID; all 20 tests in that file pass.
