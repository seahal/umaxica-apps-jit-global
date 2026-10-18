# R5-WU18A sub-cases: two-connection ordering, cached reading caller, JWKS rotation outage

- Date: 2026-10-18 UTC.
- Commit: `17903f7d121aa33efe29f2db9235c9aa5db4b001`; the worktree carried the existing uncommitted
  R1-R5 changes, on which these tests depend.
- Environment: `RAILS_ENV=test`, `PARALLEL_WORKERS=1`, `UMAXICA_ENV_FILE=.env.devcontainer.example`,
  isolated fleet `POSTGRESQL_ISOLATED_TEST_RUN_ID=20261017c1a2` with its manifest-derived
  `POSTGRESQL_TEST_PREPARE_DATABASES` (32 databases, PostgreSQL 18.6, `10.89.0.3/32:5432`).

## Cases

| WU18A row (A18R)                                                                         | Test                                                                                                                                                                                                                                                           | Result |
| ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| Callback/logout incl. unknown sid, paused two-connection ordering (TC-R5-07-002, 10-001) | `test/operations/rp_refresh_logout_concurrency_test.rb` "unknown sid callback logout and duplicate delivery serialize on independent connections" (already present; callback-first, logout-first and duplicate logout, second backend observed in `Lock` wait) | PASS   |
| Stale reading caller (TC-R5-07-001)                                                      | same file, new "logout committed on another connection denies a cached reading caller's request and callback"                                                                                                                                                  | PASS   |
| Key rotation under JWKS failure (TC-R5-04-001)                                           | `test/adapters/oidc_op_protocol_verifiers_test.rb`, new "an OP key rotation during a JWKS outage refuses the new key until a successful fetch"                                                                                                                 | PASS   |

- Commands: the two files together: 15 runs, 118 assertions, 0 failures/errors/skips; the
  concurrency file alone: 3 runs, 34 assertions, 0 failures.
- Mutation check: replacing `uncached` in `RpRequestAuthenticator#writer_session` made the
  cached-reader test fail (1 failure); the source was restored byte-identical (`cmp`).
- RuboCop on both test files: no offenses.

## Limits

The reading role resolves to the same test database as the writer, so the cached-reader case proves
writer selection and query-cache bypass, not behaviour against a lagging physical replica. Both
concurrency cases run in one process on two PostgreSQL backends; cross-process and Jump/Edge cases
remain NOT_RUN. TC-R5-03A-001 still FAILS, so the A18R NO-GO verdict is unchanged and no Gate status
changes.
