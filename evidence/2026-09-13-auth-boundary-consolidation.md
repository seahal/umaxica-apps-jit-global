# Auth-boundary consolidation evidence (2026-09-13 JST)

Branch: `feature`  
Head at evidence write: updated after leftover Auth/sign-rp + admission/sign-out contract slice.

## Environment

- Host PostgreSQL 17 on `127.0.0.1:5432`.
- Valkey via vfs-podman on `:6379`; logical DBs 0/1/2 for cache/rate-limit/auth-state.
- `RUBY_DEBUG_OPEN=false`, `TMPDIR=/tmp/umaxica-vitest`.
- Rails tests with `bundle exec rails test` on the box (`ruby 4.0.6`).

## Phase landings (pushed to `origin/feature`)

| Phase                  | Tip SHA (short)     | Notes                                                                                                  |
| ---------------------- | ------------------- | ------------------------------------------------------------------------------------------------------ |
| P1–P9 skeleton         | through `ddab9d314` | Prior session foundations                                                                              |
| P5 Valkey code cutover | `9e4b71856`         | Issue+exchange on Valkey CAS; PG `*AuthorizationCode` dropped; JTI stays in PG                         |
| P5 seven-RP wiring     | `898fc6ea4`         | Core/Side/Edit client IDs; `/sign/in`+`/sign/in/callback`; Edit Org RP; Auth/Base RP `/oidc/*` retired |
| P6/P7 stale URLs       | `d4c81a1e8`         | Dashboard and sign-out completion helper sweep                                                         |
| P5 leftover RP starts  | `0b7cfbba1`         | Core/Side/Edit `/oidc/authorization`+`/oidc/callback` retired; `/sign/in` is canonical                 |
| P5 SIDE JWT namespaces | `30e833fd4`         | Independent `OIDC_CLIENT_SIDE_*` keys; Core bridges use `core-app`/`core-com`/`core-org`               |

## Verification executed this session

### Valkey authorization-code cutover

```
bundle exec rails test \
  test/services/valkey/auth_state/authorization_code_store_test.rb \
  test/services/oidc/token_exchange_service_test.rb \
  test/services/oidc/authorize_service_test.rb \
  test/services/branch_coverage_batch3_services_test.rb \
  test/services/anomaly_reporting_and_authorize_failures_test.rb \
  test/controllers/palm/app/oidc/callbacks_controller_test.rb
```

Result (after model drop + migrate): `102 runs, 381 assertions, 0 failures, 0 errors` (one transient
batch3 binding error fixed; recheck green).

Earlier focused cutover suite before model deletion:
`94 runs, 356 assertions, 0 failures, 0 errors`.

### Seven-RP registry

```
bundle exec rails test test/values/oidc_seven_first_party_rp_clients_test.rb
```

Result: `2 runs, 69 assertions, 0 failures, 0 errors`.

Route recognition spot-check: Core/Side/Edit `/sign/in` and `/sign/in/callback` resolve; Base/Auth
`/oidc/callback` raise `RoutingError`; Base `/oauth/authorize` remains.

Pre-push `frontend-check` passed on both pushes.

## Continuation 2026-09-13 evening (JST)

Focused leftover-route suite: `36 runs, 798 assertions, 0 failures`.  
SIDE/Core first-party focused suite: `78 runs, 654 assertions, 0 failures`.  
Pre-push `bun run test:coverage`: 86 files, 1075 tests; stmts 99.82%, branches 99.71%, lines 99.81%.
Gates held.

Earlier full suite at `06ed9b64a`: `12989 runs, 78152 assertions, 115 failures, 67 errors, 2 skips`.

Focused leftover Root/RP/sign-out suite: `120 runs, 688 assertions, 0 failures` (1 skip: issue
#846).

Full `bundle exec rails test` at `ddbc49c04` (host Postgres + Valkey, `RUBY_DEBUG_OPEN=false`, ended
2026-09-14 00:54 JST): `12981 runs, 78344 assertions, 51 failures, 56 errors, 2 skips` in 631s. Not
green. Pre-push `bun run test:coverage`: 86 files, 1075 tests; stmts 99.82%, branches 99.71%, lines
99.81%. Gates held.

## Remaining gaps vs plan completion conditions

1. **Shared browser clients still registered** (`sign-rp`, `base-rails-rp`, `side-rails-rp`,
   `core-next-rp`). Auth still hardcodes `sign-rp`; Base still hardcodes `base-rails-rp`. Do not
   remove the four IDs until those surfaces stop depending on them. Native/content clients stay.
2. **Full Rails suite is still red** at `15a033bb7` (`31` failures / `54` errors). Largest remaining
   clusters: Edit Publishing `publishing_management_namespace` (~31 errors), compose `valkey-cache`,
   leftover ceremony/admission social entry, stale `/dashboard` assertions, flat-ruby/architecture
   baseline drift, Auth still hardcoding `sign-rp`.
3. **P4 call-site migration:** AuthCeremonySession + OpaqueAdmissionStore exist; most Auth/Base
   ceremony controllers not yet migrated onto opaque handoff/result + Base admission.
4. **Compose full stack** (`podman-compose --in-pod=false` primary/replica/valkey/fakecloud) not
   re-validated; host Postgres + Valkey used. Compose contract tests still expect `valkey-cache`.
5. **SIDE surface JWT** (`JWT_SIDE_*` / `SURFACE_NAMESPACES`) was not added. Only OIDC client
   assertion namespaces (`OIDC_CLIENT_SIDE_*`) were wired, matching the existing CORE/EDIT pattern.

## Continuation 2026-09-14 early morning (JST)

Retargeted leftover Auth/`sign-rp` backchannel and post-admission ceremony contracts on `feature`:

- `OidcRpLogoutReceiversTest` now covers routed first-party receivers only (`core-app` / `core-com`
  / `core-org` / `edit-org`). Auth ceremony hosts stay unrouted for RP backchannel.
- Sign-up suspension open/unaffected cases redeem Base opaque admission before asserting 2xx.
- Sign-out completion destinations assert `/sign/out` (not `/lobby` or `/sign/out/complete`).
- CSRF protocol-exception coverage uses Core backchannel instead of retired Auth helper.
- Auth settings SSO browser-flow hits literal `/oidc/callback` (helper retired; 404 early-return).
- Flat Ruby mapping inventory falls back to `git grep` when sandbox filters system `rg`.

Focused verification: `136 runs, 1062 assertions, 0 failures, 0 errors` across receivers,
suspension, Auth/Base/Palm sign-out, CSRF, client registry, Core route contract, and mapping.

Full `bundle exec rails test` at `15a033bb7` (host Postgres + Valkey, `RUBY_DEBUG_OPEN=false`, ended
2026-09-14 01:18 JST): `12981 runs, 78465 assertions, 31 failures, 54 errors, 2 skips` in 670s. Down
from `ddbc49c04` (`51` failures / `56` errors). Pre-push frontend-check held.

Largest remaining clusters: Edit Publishing `publishing_management_namespace` (~31 errors), compose
`valkey-cache` (~6), leftover ceremony/admission social entry, stale `/dashboard` assertions,
flat-ruby/architecture baseline drift. Shared browser clients still registered; Auth still hardcodes
`sign-rp` for RP logout launch / `oidc_client_id`.

## Continuation 2026-09-14 morning (JST)

Pushed slices on `feature` (hooks green, no `--no-verify`):

| Tip SHA (short) | Notes                                                                                                                                                                  |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `a6c7bc195`     | Edit Publishing cell namespace no longer shadowed by `PublishingManagementCell`; compose/portability guards retargeted to single nonprod `valkey` (logical DBs 0/1/2). |
| `e77f093c0`     | Auth ceremony admission uses `cross_host_redirect_allowed?`; Valkey nested packages allowlisted for flat-ruby; architecture baseline regenerated after visibility fix. |
| `aabc399af`     | Social completion asserts Base `/` (retired `/dashboard`); staff Entra `/sign/in` redeems opaque admission.                                                            |

Focused green before push: Publishing CMS 50/978; compose Valkey contracts 25/213;
architecture/flat-ruby/redirect invariants 16/3112; social/Entra/dashboard leftovers 66/550.

Full `bundle exec rails test` at `aabc399af` (host Postgres + Valkey on `:6379`,
`RUBY_DEBUG_OPEN=false`, ended 2026-09-14 01:45 JST): **12981 runs, 78995 assertions, 21 failures,
18 errors, 2 skips** in 698s. Down from `15a033bb7` (`31` failures / `54` errors).

Follow-on uncommitted-at-evidence-write leftovers addressed next: social ceremony entry admission,
logout completion harness vs Valkey notice store, Edit bare-controller inventory, health `/app`
false positive, Base/Core sign-out `destroy` route without action, Edit standalone title allowlist.

### Remaining blockers

1. **Auth still hardcodes `sign-rp`** (`Auth::*::ApplicationController#oidc_client_id`, Auth OIDC
   callbacks, Auth sign-out RP launcher, settings/passkey authorize). Base still hardcodes
   `base-rails-rp`. Do not remove shared browser clients until those call-sites migrate;
   native/content stay.
2. **Ceremony/admission leftovers still red in the aabc399af suite** (auth region contract,
   sequence-gate OIDC register, OIDC resume, identity authority guards, Base authority route
   contracts, coverage-threshold OIDC edges, host-family/sign route-host).
3. **Vite/html title / health revision / RI routing** contract drift outside the Auth RP cutover.
4. Compose full stack (`podman-compose --in-pod=false`) not re-validated this session; host Valkey
   used.

## Continuation 2026-09-14 mid-morning (JST)

Tip `5bfdb01a7` full suite (host Postgres + Valkey, `RUBY_DEBUG_OPEN=false`, ended 2026-09-14 01:59
JST): **12981 runs, 79008 assertions, 18 failures, 18 errors, 2 skips** in 667s. Prior same-day at
`aabc399af`: 21 failures / 18 errors.

Follow-up on that tip: Base/Core route contracts still expected DELETE `/sign/out` → `destroy` after
the unused destroy action was retired; contracts updated to assert DELETE is unrouted (sign-out
stays on show/new/edit/create).

### Remaining blockers (tip suite)

- Auth still hardcodes `sign-rp`; Base still hardcodes `base-rails-rp` (shared browser clients not
  removable yet).
- Ceremony/admission: auth region contract, OIDC authorization resume, sequence-gate
  `register_result_and_issue_resume!` harness (`transaction` missing), identity authority guards,
  Base authority route contracts.
- Coverage-threshold OIDC edges / controller helpers; host-family + sign route-host; RI routing;
  health revision; Vite/html title contracts; sessions controller leftover.

## Conclusion

P5 Valkey authorization-code exchange cutover and seven-RP controller/route wiring are pushed on
`feature` with hooks green. Plan absolute completion still requires P4 ceremony call-site migration,
shared-client retirement after seven flows, full Rails/coverage/browser suites, and evidence/ADR
polish for those closures.
