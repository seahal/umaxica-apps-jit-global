# Dashboard menu-link revalidation

- Date: 2026-09-22 UTC
- HEAD: `277673d13547d722fc88f830711eee69b923a7e8`
- Scope: read-only revalidation of the signed-in Base app/com/org Dashboard navigation contract.
- Worktree: existing user and agent changes were preserved; this record is an additional local
  evidence file and no unrelated changes were reverted.
- External writes: none; no GitHub, AWS, Cloudflare, provider, production, shared database, email,
  or SMS service was contacted.

## Current implementation

The three surface root controllers render the signed-in Dashboard through the existing Inertia
props contract. Each returns `Menu links` before `Primary links` and generates URLs through the
existing Rails route helpers with the request-context parameters. The app surface uses its existing
`Switcher` route; com and org preserve their existing surface-specific `Selector` route rather
than inventing a feature that is not present on those surfaces. All three surfaces use the shared
Menu section classification and keep the existing surface-specific primary links.

- `app/controllers/base/app/roots_controller.rb`
- `app/controllers/base/com/roots_controller.rb`
- `app/controllers/base/org/roots_controller.rb`

The menu entries are constructed from route helpers for the switcher/selector, preference, and
logout pages. The primary-link arrays do not repeat those URLs. No route, authentication,
authorization, domain, API, JSON, or global-header behavior is changed by this contract.

## Evidence in tests

The public rendered-Inertia-props tests cover all three surfaces:

- `test/controllers/base/app/welcome_dashboard_authority_slice_1c_test.rb`
- `test/controllers/base/com/welcome_dashboard_authority_slice_1c_test.rb`
- `test/controllers/base/org/welcome_dashboard_authority_slice_1c_test.rb`

They assert section ordering, intended menu URLs, absence of duplicates in primary links,
preservation of the remaining links, surface-specific differences, and propagation of `ri`, `ct`,
`lx`, and `tz` into every menu URL. The app test also verifies that the rendered dashboard does
not expose machine-protocol or sign-in URLs.

## Adversarial result

- No Dashboard page route was added; Rails still owns the existing root-based signed-in page.
- No URL string concatenation or cross-surface route substitution was found in the menu-link
  construction.
- The absence of a com/org `Switcher` implementation is not treated as a defect: their existing
  selector route is exposed under the unified Menu classification, as required by the surface
  boundary.
- No new UI abstraction or domain logic is required because the existing Dashboard component
  already consumes arbitrary sections.

## Disposition

`ACCEPTED_AS_EXISTING_IMPLEMENTATION` for the Dashboard Menu/Primary separation. The current
Compose-backed test evidence recorded in the hardening plan covers the selected reachability set;
this review did not rerun Rails tests outside the Compose service. Live deployment reachability
remains unverified.

