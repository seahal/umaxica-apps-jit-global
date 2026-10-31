# WU-3 corporate anonymity: surface, test and documentation closure

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`
- The worktree contained extensive uncommitted WU-3 implementation, documentation and test
  changes from several agents, plus pre-existing WU-1 edits. Results apply only to this
  worktree state; nothing was committed.
- Scope of this record: the final corporate (`com`) removal items left open by the preceding
  WU-3 work — obsolete corporate test removal, corporate branches in shared parameterized
  tests, the orphaned corporate identity UI, and the verification of the whole worktree.

## Outcome

- Base com and Warp com are anonymous surfaces. `Base::Com::ApplicationController` and
  `Warp::Com::ApplicationController` install `ComAnonymousActorContext` and clear it after the
  request; neither reads a principal, credential, session, admission, or RP cookie.
- Auth, Visa and Core corporate hosts have no route. `GET /` reaches `unknown_hosts#show` (404);
  every other path is an unrecognised route.
- No corporate host publishes JWKS, runs a credential ceremony, or keeps a Preference
  cookie/theme API. The sixteen Jump namespaces including the `*_COM` entries stay registered;
  the corporate ones have no publishing host.
- Full Ruby suite: 17,525 runs, 143,708 assertions, 139 failures, 218 errors, 0 skips. Every
  failing identifier is in `plans/2026-10-28-baseline-failing-tests.md`; 0 new identifiers, and
  624 baseline identifiers now pass.
- JavaScript suite: `bun run test` — 96 files, 1,052 tests, all passing.

## Commands and results

| Command | Result |
| --- | --- |
| `bin/rails test` | 17,525 runs, 143,708 assertions, 139 failures, 218 errors, 0 skips |
| failing-identifier diff against `plans/2026-10-28-baseline-failing-tests.md` | 357 failing, 0 new, 624 baseline identifiers now passing |
| `bin/rails test test/controllers/base/com test/controllers/warp/com test/integration/routes/{base_authority_route_contract,warp_route_contract,preference_api_route_contract,auth_base_root_contract,neutral_rp_entry_contract}_test.rb test/integration/preference_web_csrf_test.rb test/integration/jump_rt_issuer_jwks_authority_test.rb` | 83 runs, 1,285 assertions, 0 failures, 0 errors |
| `bin/rails test test/integration/routes/com_social_boundary_test.rb test/integration/contact_settings_otp_atomic_commit_test.rb test/integration/contact_registration_otp_bootstrap_receipt_recovery_test.rb test/integration/acceptance_wu29_sign_entry_sentry_blocked_test.rb` | 7 runs, 222 assertions, 2 failures (both pre-existing app settings failures in the baseline list) |
| `bin/rails test test/lib/runtime_role_route_ownership_test.rb test/controllers/base/identity_read_only_pages_test.rb` | 22 runs, 136 assertions, 0 failures |
| `bin/rails zeitwerk:check` | passes |
| `bin/rails routes` | exit 0 |
| `bun run test` | 96 files, 1,052 tests, 0 failures |
| `bun run openapi:bundle` | regenerated `openapi/bundled/openapi.com.yml` byte-identically |
| `bundle exec rubocop` on the four edited test files | no offenses |

## Corporate test removal and conversion

Removed, because the behaviour they assert is corporate credential behaviour that no longer
exists (no skips, no replacements with mocks):

- `test/integration/com_social_login_blocked_test.rb` — the corporate sign-in page and the
  `core-com-jp` authorization challenge it drove are gone. `ComSocialBoundaryTest` now also
  asserts that the bare `/social/{google,google_org,apple}` and `/auth/google_com` entry points
  on the corporate Auth host are unrecognised for both verbs, which is the stronger form of the
  old 404 assertions. `AppSocialLoginWorksTest` and `OrgSocialLoginBlockedTest` keep the
  surviving app and org behaviour.
- `gait/features/auth/auth_com_signup_screens.test.tsx` — every screen it rendered was a
  corporate sign-up/verification page deleted by WU-3.
- `gait/features/base_com/base_com_identity_*.test.tsx` and `src/features/base_com/identity/**` —
  after the corporate identity controllers and Inertia pages were deleted, nothing rendered
  these components; only their own tests imported them.

Converted from a corporate/app parameterization to the surviving app surface:

- `test/integration/contact_settings_otp_atomic_commit_test.rb`
- `test/integration/contact_registration_otp_bootstrap_receipt_recovery_test.rb`
- `test/integration/acceptance_wu29_sign_entry_sentry_blocked_test.rb`

Renamed, because the shared credential screens they exercise are no longer corporate-owned:

- `gait/features/auth/auth_com_screens.test.tsx` → `auth_shared_screens.test.tsx`
- `gait/features/auth/auth_com_interaction.test.tsx` → `auth_shared_interaction.test.tsx`
- `vitest.config.ts` node-spec list updated accordingly.

## Deferred: corporate OP authority-stop participant removal

`OpAuthorityStopCommitter::REALMS` still carries the `com` entry, and the
`OpComAuthorityStop*` models remain. Removing them now regressed 33 visitor lifecycle and
revocation tests, because shared services, jobs and revocation paths still name the corporate
realm. WU-4 owns removing those shared corporate references before the models are deleted, so
the removal was reverted rather than papered over with guards. `two.md` §3.2 asks for the
participant removal in WU-3, which conflicts with the §1.2 ordering that makes WU-4 the owner of
shared-service corporate references.

## Documented discrepancies

1. `two.md` §3.2 removes the Warp corporate Preference cookie/theme API, `dashboards#show`,
   sign/oidc routes and JWKS, while appendix I rows for `warp/com/api/v0/preferences/{cookies,
   themes}_controller.rb`, `warp/com/dashboards_controller.rb` and
   `warp/com/well_known/jwks_controller.rb` say "keep the public part". Since the removed
   controllers were authenticated or OIDC-only, §3.2 was followed.
2. `two.md` §3.2 asks for the OP participant removal inside WU-3; §1.2 and the actual dependency
   graph put it in WU-4 (see above).
3. `docs/reference/subdomains.md` still listed `auth.com.localhost` as a credential gateway, and
   `docs/architecture/base-auth-seven-rp-boundary.md` still listed corporate Visa, Auth, Base,
   Core and Warp as OP/ceremony/RP participants. Both were corrected in this worktree.
4. `docs/operations/jump-rt-visa-edges.md` still described the corporate Jump edges as active;
   the document now states that the `*_COM` namespaces stay registered without a publishing host.
5. `docs/architecture/oidc-non-participant-surfaces.md` did not list Base com or Warp com; both
   are now listed as anonymous non-participants.
6. `docs/architecture/cloudflare-request-paths.md` still maps `jp.umaxica.com` and the corporate
   hosts at the tunnel layer. That mapping is external Cloudflare configuration, not repository
   routing, so it is left for WU-6/WU-X1.
7. `docs/reference/ui-view-inventory.md` is an explicitly dated snapshot (2026-10-05) and was not
   rewritten.

## Not performed

No database change, migration, seed, external system call, dependency change, or commit. The
corporate databases, `config/database.yml` bindings and health profiles remain for WU-4 and
WU-5.
