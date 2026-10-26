# Global browser region canonicalization

Revision: `bde2346c17e2aa911acc95de1f6035f80498f2da`, with extensive pre-existing staged and
unstaged work plus this uncommitted change. Scope and acceptance:
`specs/global-region-canonicalization/spec.md`.

## Delivered behavior

- Base APP/COM/ORG Home/Dashboard delegate HTML region handling to the existing shared
  `PreferenceGlobal#set_region`. The former in-place-only exception remains only for the existing
  JSON representation contract. Browser GET/HEAD without valid region canonicalize the same path.
- Visa APP/COM/ORG RootsControllers explicitly include `PreferenceGlobal` and register
  `before_action :set_region`. Their protocol BareControllers do not change. The previous root
  region exemptions were removed from the invariant test; roots still issue no cookies.
- Auth, Tech and Edit already use the common callback. No extra redirect implementation or hardcoded
  region default was added. Valid query context survives, `jp` and `us` stay selected, malformed
  values use the existing normalization, and the default anonymous context is `jp`.
- Base Home's final authenticated 404 is retained after the query redirect. Tests asserting the
  former no-redirect contract now follow canonicalization and retain their page/security assertions.
- The Home/Dashboard and Visa ADRs, preference architecture and AUTH-35 checklist document the
  owner's new requirement. Regional and Publishing behavior and existing protocol/JSON/metadata/
  health exemptions remain outside the change.

## Verification

- Red: `bin/rails test test/integration/global_region_canonicalization_test.rb`:
  three tests/11 assertions, two failures (Base returned 200 without canonicalization).
- Green: same file, three tests/259 assertions, no failures/errors/skips. The matrix includes
  eleven Global host roots on GET/HEAD, blank/unknown/malformed region partitions, nearest format
  neighbors `j`/`jp`/`jpp`, explicit `jp`/`us`, same-host/path query preservation and Visa metadata.
- Initial root regression: 54 tests/608 assertions, no failures/errors/skips.
- **Final combined run: 152 tests, 2,416 assertions, zero failures/errors/skips**. Command:
  `bin/rails test` with these groups (braces abbreviate actual file arguments):
  - `test/integration/{global_region_canonicalization,visa_roots,acme_roots,visa_authorization_start_boundary,visa_authorization_continuations,base_same_origin_handoff,oidc_initiated_sign_in_completion,oidc_rp_browser_flow,root_login_establishment_flow}_test.rb`
  - `test/controllers/{base,auth}/{app,com,org}/roots_controller_test.rb`
  - `test/controllers/{tech,edit}/org/roots_controller_test.rb`
  - `test/controllers/base/{oidc_result_browser_binding,oidc_result_csrf_transport}_test.rb`
  - `test/controllers/controller_inheritance_invariant_test.rb`
  - `test/unit/security/{ri_routing_contract,authentication_mode_inventory,forbidden_rails_patterns,standard_csrf_invariant,identity_authority_inversion_guard}_test.rb`
  - `test/security/invariants/csrf_verification_strategy_invariant_test.rb`
- **Actual Chromium 156.0.8078.47** through Playwright against the running development application:
  Base/Auth/Visa x APP/COM/ORG, nine hosts. Initial `/?lx=en&marker=preserved` finished at the same
  origin/path with `ri=jp` and the original marker. An explicit `/?ri=us` returned 200 without a
  redirect on each host. All eighteen navigations passed. Command:
  `bun tmp/global-ri-browser-check.mjs`; local-only resource routing blocked external requests.
- RuboCop on six affected controllers and seven tests: 13 files, no offenses. Scoped whitespace
  checks passed.

The full Rails suite, external Jump integration and public deployment were not run. No schema,
persisted preference change, production mutation or external write was performed.
