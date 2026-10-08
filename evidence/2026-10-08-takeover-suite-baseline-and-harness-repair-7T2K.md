# Takeover: full-suite baseline and test-harness repair

Commit: `6405c465c82dd45625d294ad8f8c2fe7827a4390`. The worktree had uncommitted changes that affect
every result below: the previous agent's in-progress identifier/OTP work (about 50 paths) and the
changes described here.

`bin/rails test` (16 workers, about 200 seconds), no extra environment, local test fleet verified by
`Umaxica::TestEnvironment::DatabaseSafety.verify_catalog!`:

| Run                                                                  | Result                                                    |
| -------------------------------------------------------------------- | --------------------------------------------------------- |
| First stable run after the other agent was stopped                   | 14,841 runs, 797 failures, 258 errors, 1 skip             |
| After the changes below                                              | 14,841 runs, 491 failures, 199 errors, 1 skip (250 files) |
| After the sign-start and RP response fixes                           | 14,841 runs, 471 failures, 232 errors, 1 skip (268 files) |
| At commit `4bb90565f` (D4, D5, D2, RP credential tests, stable runs) | 14,911 runs, 462 failures, 199 errors, 1 skip (238 files) |

The Task 0.1 baseline record executed no assertion (Bundler could not materialize Rails), so no
failure can be classified as pre-existing. Every remaining failure is unclassified.

## Environment findings (repaired, not encoded as tests)

- Migration-owned reference rows were absent from the three ticket test databases although their
  seed migrations were recorded as applied: `*_sign_in_flow_states` (org),
  `*_sign_up_flow_statuses`, `*_sign_up_flow_cleanup_statuses`, `*_sign_out_flow_statuses`,
  `*_sign_out_flow_kinds`, `*_session_limit_resolution_states`. Re-ran the migrations' own
  idempotent `INSERT ... ON CONFLICT DO NOTHING` statements. This removed 128 foreign-key errors and
  88 missing-translation errors.
- `ParallelTestDatabaseCloner` judges worker-clone freshness from schema and migration files only,
  so clones made from a base without those rows stayed stale. Their stamps were invalidated with
  `COMMENT ON DATABASE` and the next run rebuilt them. The digest still ignores row data.
- Three ownerless identifier rows created on 2026-10-08 (`ClientTelephone` 756, `VisitorEmail` 963,
  `VisitorTelephone` 748) made `identifier_encryption_rotation_drill_test.rb` fail; that failure
  carries an encrypted record the parent process cannot unmarshal, which hung two full runs. The
  user approved deletion; the rows were revalidated (test database, exact ids, absent owners) and
  deleted, and the zenith worker clones were invalidated.
- A full run also hung once when the worker socket under `tmp/` disappeared. Not reproduced.

## Changes

- Test harness: 630 file-local copies of `as_user_headers`/`as_staff_headers`/`as_visitor_headers`
  and 189 copies of `jwt_access_token_for` shadowed the shared harness and sent only the root
  cookie. They were removed; `authenticated_resource_headers` now also issues a real RP Session and
  RP cookies for the Browser RP client that routing assigns to the host.
- Production: `PublishingManagementCell` and `BaseAppAvatarSocialGraphActions` called
  `authenticate_operator!`/`authenticate_client!`, which Browser RP controllers no longer define;
  they now use `authenticate_browser_rp!`. `BrowserRpAuthentication` detaches a refused credential
  on a public HTML page and renders it anonymous instead of answering 401.
- Tests migrated to current contracts: burst rate limits (admitted through the D-82 exchange, 28
  pass), JWT registry key fixture (24 pass), root-login surface tests moved to the Authority
  controllers (52 pass), sign-in `state_id` API, two concern test doubles.
- Two thread-connection leaks in `session_limit_resolution_transactionable_test.rb` and an unsafe
  teardown in `enforcement_identifier_digest_test.rb` that cascaded into 147 errors.
- Decision recorded in `adr/home-dashboard-authentication-boundary.md`: anonymous Base `/dashboard`
  goes to the passive `/sign` page.

- Production, found through `base_dashboard_authentication_guidance_test.rb` (21 pass): the RP sign
  start and the `/oauth/authorize` ceremony start answered 302 to a POST where D-82 requires 303;
  the ceremony start form dropped `ri`, so the Auth entry URL was built without a region; an
  unauthenticated RP request now answers JSON with 401 and an Inertia visit with 409 and
  `X-Inertia-Location`. Sixteen assertions that pinned 302 were updated to the observed 303.

Between consecutive full runs about 50 failures appear and disappear with the seed (connection-pool
timeouts and concurrency tests). They are not yet isolated.

## Later findings in the same session (development-side verification)

- Full runs hung for three separate reasons, all removed: ownerless identifier rows (four empty
  fixtures now truncate the identifier tables), pooled test threads that kept database leases
  (twenty blocks now release them; connection-pool timeouts went from 24 to 0), and one test that
  waited forever on a queue when a thread failed before signalling.
- `browser_rp_authentication_test.rb` executed no assertion: its probe controller lacked the
  authentication concern and all five tests raised. It now runs 40 tests and 85 assertions covering
  issuer, audience, client, subject, Browser Session, malformed values, exp plus leeway at -1/0/+1
  second, revoked and missing parents, refresh values, and unsafe requests (failed CSRF or
  `Origin: null` gives no rotation and no mutation; a successful refresh gives exactly one).
- The Browser RP credential is validated against its live chain on every request. D-53 describes
  offline verification; the implementation is stricter. Not changed; decision requested.
- Base `/welcome` raised after every sign-in (no `authorize!`, and root sequence methods the self-RP
  controller no longer inherits). Fixed; the page follows a verified return target only.
- `session_limit_hard_reject` is removed in all realms; a model-refused login is retried once under
  the actor lock into the ordinary resolution, otherwise `session_limit_conflict` (503).
- D-07: 25 of the 35 dynamic-dispatch lines added to `app/` are now explicit. Six keep a pattern
  present at the baseline; four are `respond_to?(:to_time)` input checks.
- D-110 (`test/test_helper.rb`, new `test/support` helpers) is not corrected: an exception was
  requested and no decision has been received.

## Not done

`two.md` tasks 16.1, 16.3 to 16.6, 19.2 to 19.4, 23.1, 23.3 and 23.4 remain unchecked. The
`three.md` audit has only its structural sections (5.1 to 5.3, 7) observed; sections 6 and 8 are not
complete. `bun run test`, lint, typecheck, build and `db:verify_no_schema_drift` were not run.
