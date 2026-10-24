# WU-02 Visa OP / Base RP host separation

Revision: `ba570a0007b1d40eabe32990a34831317fd98a93`.

Observed 2026-10-24. The worktree was already uncommitted and contained unrelated WU-01/WU-05,
security, schema, test and documentation changes; no reset, clean, restore, deployment, production
credential mutation or external write was performed.

## Delivered boundary

- `visa.umaxica.{app,com,org}` is the Visa OpenID Provider surface.
- `www.umaxica.{app,com,org}` remains the Base browser RP surface.
- Base RP, Visa OP and Auth now use distinct host-only Rails sessions.
- Visa has `VISA_APP`, `VISA_COM` and `VISA_ORG` JWT namespaces and JWKS routes; Base keeps its
  `BASE_*` Jump/RP material.
- Base routes no longer own the OP OAuth/OIDC endpoints. Visa routes own discovery, JWKS, OAuth,
  logout, sign-bye, limitation and edge-token endpoints with per-realm host constraints.
- Sign-in-path ceremony binding confirmations run on Visa; re-verification confirmations remain on
  Base and reject the opposite purpose set.
- Base `/welcome` and `/selector` use RP state only. They do not read Visa-written Rails-session
  gates or phase bindings.
- Jump/Edge implementation remains outside this request; the corresponding dirty-worktree files were
  preserved and are not part of the scoped completion commit.
- App social sign-up ceremony grants use `VISA_APP`; Step-Up/re-verification grants remain in the
  Base namespace.

## Verification performed

- Host configuration boot probe with all other production host inputs supplied and
  `PUBLIC_VISA_SERVICE_URL` absent: failed closed with
  `KeyError: Missing required ENV key: PUBLIC_VISA_SERVICE_URL`. Configuration construction was run
  directly, not added as a Minitest subject.
- `bin/rails test` final WU-02 gate covering host values, route ownership, JWT/Jump edges, Base RP
  welcome/selector behavior, logout, root handoff, route/base-class invariants and architecture
  guards: **153 runs, 4,471 assertions, 0 failures, 0 errors, 0 skips**.
- OIDC result transport, OIDC initiated sign-in, social ceremony contract and RuntimeRole boundary:
  **43 runs, 480 assertions, 0 failures, 0 errors, 0 skips**.
- `bin/rails zeitwerk:check`: passed; only the existing `vendor/rails_db` eager-load warning was
  reported, followed by “Otherwise, all is good!”.
- `git diff --check`: passed.
- The broader Rails suite was run earlier with the three inline Visa public URL settings: **18,461
  runs, 150,360 assertions, 481 failures, 266 errors, 0 skips**. This is not reported as a green
  suite; the failures include the existing WU-05/social and external-owner-API groups plus tests
  that still assume the pre-split Base OP.

## Unverified follow-up groups

These were not weakened or counted as successful WU-02 evidence:

- `test/integration/org_root_login_establishment_test.rb`: the Visa handoff reaches the Base RP, but
  its later WU-27 Passkey-registration/settings continuation still expects the former sequence.
- `test/controllers/base/oidc_result_browser_binding_test.rb`: its final replay setup assumes the
  old Base root page can provide a CSRF token; Visa has no RP root page.
- `test/integration/social_auth_app_flow_contract_test.rb`: three failures remain in the WU-05
  canonical sign-in/finalization loops after the initial Visa handoff re-pointing. They are not
  treated as proof of a Visa boundary regression.

These groups require their owning WU-05/WU-27 test-flow migration before they can certify the full
cross-unit suite.

## Reconciliation

The current WU-02 browser migration was completed after this initial record: the RP browser flow and
ORG OIDC handoff tests now follow Visa authorization/result resources and the Design D navigation
contract. The broader Rails suite remains non-green and is not represented as a WU-02 acceptance
result.
