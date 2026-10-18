# Jump rt SIGN_* issuer origin (2026-09-28)

Commit: f8c93e4a9a50e22a942976a5810962f039662206, with uncommitted changes. The worktree also held
unrelated uncommitted changes from concurrent work, which were left untouched.

## Observed defect

- `Auth::App::Settings::{Googles,Apples}Controller#show` and `Verification::SetupsController#new`
  sent unauthenticated users to Jump with a SIGN_APP rt. Jump answered `400`,
  `x-jump-error: invalid_request`, and the browser landed back on Base `/identity`.
- The SIGN_APP rt carried `iss: https://log.umaxica.app` (no DNS record, no JWKS) and
  `kid: development-sign-app-es384-a`. That kid is published by `https://auth.umaxica.app/.well-known/jwks.json`.
- `JumpRtReturnPolicy.env_base_and_core_sources` built `https://https` sources, because it prefixed
  full origins with `https://`.

## Black-box gateway probe (dev keys, via Cloudflare)

| rt namespace / iss | url | Jump |
|---|---|---|
| SIGN_APP, iss log (old) | www.umaxica.app | 400 |
| SIGN_APP, iss log (old) | auth.umaxica.app/sign/in | 400 |
| SIGN_APP, iss auth (fixed) | www.umaxica.app | 302 |
| SIGN_APP, iss auth (fixed) | auth.umaxica.app/sign/in | 400 |
| BASE_APP, iss www | auth.umaxica.app/sign/in | 302 |
| BASE_APP, iss www | www.umaxica.app | 400 |
| SIGN_COM, iss auth.com | auth.umaxica.com/sign/in | 400 |
| BASE_COM | auth.umaxica.com/sign/in | 302 |

The gateway refuses same-origin rt (`url` origin == `iss`). The Auth protected-page redirect still
targets its own `/sign/in`, so those three pages still fail after the issuer fix. That residual
failure is left unfixed, pending an admission state-machine decision.

## Tests

- Failing first: `test/integration/jump_rt_issuer_jwks_authority_test.rb` (6 failures: iss log.*,
  and a 404 JWKS at the iss origin). The added return-policy tests also failed first.
- After the fix: focused set, 185 runs, 0 failures. Full `bin/rails test`: 12086 runs, 0 failures,
  0 errors, 2 skips.

## Follow-up: Auth protected-page hand-off (option 1)

- Jump worker log for the residual failure: `jump_reject reason=invalid_dst`,
  `iss=https://auth.umaxica.app`, `dst_origin=https://auth.umaxica.app`.
- Auth app/com/org `sign_in_url_with_pt` now targets the Base root of the surface (boot host
  registry), cross-origin from the Auth issuer.
- Failing first: the three `anonymous sign settings hands off cross-origin to the base admission
  entry` tests (app/com/org settings controller tests).
- Real path via Cloudflare, logged out: `/settings/google`, `/settings/apple`, and
  `/verification/setup/new` each go Auth 302 → Jump 302 → `www.umaxica.app/?ri=jp&rt=…` → 303
  (rt verified and stripped) → 200.
- Auth, integration, and jump_rt tests: 2478 runs, 0 failures. The full suite result is in the
  session report.
