# Integrated Auth/Avatar/Warp remaining pass (2026-09-26)

HEAD: `310745dc291913c5b9baaae76738442c4ec9ff1d`, with a large pre-existing dirty worktree
(about 297 entries at start). Another agent (`codex` process) edited the same worktree during this
pass, including the step-up cancellation controllers and tests and
`app/controllers/auth/org/sign/in/challenge/passkeys_controller.rb`. Those files were not touched
here. Ledger: `plans/backlog/2026-09-26-integrated-auth-remaining-ledger.md`.

## Owner decisions recorded

Option A for both proposals in
`plans/backlog/2026-09-25-avatar-image-and-emergency-credential-decisions.md` was approved by the
owner on 2026-09-26. ADRs: `adr/base-dashboard-avatar-image-delivery.md`,
`adr/emergency-secret-credential-commit-acknowledgement.md`.

## Changes in this pass

- Avatar image proxy: `app/controllers/base/{app,org}/dashboard_avatar_images_controller.rb`,
  routes in `config/routes/base.rb`, `BaseSwitcherAuthority#selected_avatar`,
  `Avatar#image_cache_key`, Dashboard props in `base/{app,org}/roots_controller.rb`,
  `src/features/auth/SurfaceDashboard.tsx`, `app/assets/images/base/default_avatar.png`.
- Emergency contract: `app/operations/client_emergency_secret_credential_sign_in_operation.rb`,
  `app/models/client_emergency_sign_in_operation.rb`, migrations
  `db/app_tickets_migrate/20260926170000_*` and `db/app_zenith_migrate/20260926170000_*`
  (applied to local development and test databases only). The endpoint stays inactive.
- `lib/tasks/legacy_login_secret_inventory.rake` (read-only).

## Results

| Check | Result |
| --- | --- |
| Full suite, before changes (`RUBY_DEBUG_ENABLE=0 PARALLEL_WORKERS=1 bin/rails test`) | 11,971 runs, 12 failures, 1 error, 2 skips. Not a clean baseline: route-inventory and file-based tests picked up this pass's in-progress files, and the concurrent edits were in flux. |
| Full suite, after changes (same command) | 12,004 runs, 77,052 assertions, 2 failures, 0 errors, 2 skips. The tree fingerprint differed before and after the run (concurrent edits). Failure 1: `ForbiddenRailsPatternsTest` lists new `auth/*/verification/cancellations_controller.rb` skips from the concurrent work. Failure 2: `ObjectPlacementTest` for this pass's operation file name; fixed by renaming, then rerun below. |
| Emergency operation + object placement + architecture baseline, after rename | 26 runs, 1 failure: the architecture baseline lists `auth/org/sign/in/challenge/passkeys_controller.rb` as resolved, caused by the concurrent edit to that file. |
| `test/operations/client_emergency_secret_credential_sign_in_operation_test.rb` | 15 runs, 0 failures. Covers expiry at −1s/at/+1s, 4/5/6 failure cap, mismatch-only counting, rollback, stop after session commit, lost response, forged operation, unknown outcome, `app_ticket` outage, 4-way concurrent claim and consume on independent connections. |
| App/org Avatar image tests and Dashboard tests | Passing (app 10, org 6 image tests; Dashboard slice tests updated for the new prop). |
| `bun run test -- spec/features/dashboards/base_dashboard_identity.test.tsx` | 6 passed. |
| Recheck batch (Jump RT, Warp SSO, recovery-secret one-time reveal incl. parallel GET, Preference 401/recovery, cookie invariants, regional RP matrix, Turnstile, ceremony concurrency) | 193 runs, 0 failures. |
| Dev server HTTP check of Avatar image (fakecloud storage) | `/dashboard?ri=jp` 200 with the image `src`; image 200 `image/png`, bytes equal to the upload; `Cache-Control: max-age=0, private, must-revalidate`; `If-None-Match` → 304; anonymous → 302; only the development profiler cookie set. The missing local `fakecloud` Avatar bucket was created for this. |
| Browser render | Not done: no Chromium installed in this environment. |
| Turnstile Siteverify, real service | Cloudflare public test secrets through `JitSecurityTurnstileVerifier.verify`: pass → success, always-fail → `invalid-input-response`, spent → `timeout-or-duplicate`. Site keys were not available; ceremony hostname binding was not verified. |
| Vite HMR | Observed over HTTP, not in a browser: primary socket targets Rails (404 on upgrade); the `localhost:3036` fallback upgrades (101). |
| `bin/rails auth:regional_rp_contract` | `complete: false`; the same 12 cells as before are missing audience or host. |
| `bin/rails authority:cutover_guard` (dev DB) | `ready: false`; app `client_persona` and `enterprise` each have one unresolved row. Target data not inspected. |
| `bin/rails secret_credentials:legacy_login_inventory` (dev DB) | 1 legacy LOGIN row, active, not revoked. No write performed. |

No production data, production keys, OIDC registrations, deployments, or GitHub writes were touched.
