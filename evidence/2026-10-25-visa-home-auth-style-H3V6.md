# Visa public homepage presentation

Revision: `bde2346c17e2aa911acc95de1f6035f80498f2da`, with extensive pre-existing uncommitted
authentication-cycle changes and this uncommitted UI change. The owner requested an Auth-like
homepage for the three Visa domains.

## Delivered presentation

- The three surface-local ERB roots now have Auth-style brand chrome, edition tint, landing
  typography, the existing shared landing description, a translated sign-in link, display
  preferences and copyright. The existing stylesheet and skip-link/copyright partials are reused.
- Sign-in links target the matching Base RP neutral entry; preference links target that Base
  surface's preference page. Configured origin scheme/host/port and supplied region are preserved.
  No context-free Auth ceremony, authorization start or new form was added to Visa root.
- The roots remain on their own BareController and do not issue cookies. Existing theme-cookie
  presentation and system light/dark appearance are honored. The shared CSS additions are scoped
  to `.ui-landing`; no React runtime or new frontend stack was introduced.
- English/Japanese sign-in labels were added to the existing two locale bundles. Current root
  ownership and region-exemption rationale were updated in the Visa ADR, UI inventory and guard.

## Checks actually performed

- `bin/rails test test/integration/visa_roots_test.rb test/integration/unknown_host_root_test.rb
  test/unit/security/ri_routing_contract_test.rb`: **13 tests, 193 assertions, zero
  failures/errors/skips**. Includes six public/local hosts, heading/chrome, matching Base
  destinations with region propagation, theme cookie, both languages, empty HEAD, no Set-Cookie
  and look-alike-host refusal.
- RuboCop on the three roots and two affected tests: five files, no offenses.
- ERB lint on the three root documents: no errors; the existing Ruby parser-version warning was
  emitted. `oxfmt --check app/assets/stylesheets/application.css` and scoped whitespace checks pass.
- **Actual Chromium 156.0.8078.47**, launched through the installed Playwright package, loaded
  the running development Rails application on port 3000. The Auth COM root was inspected as the
  visual reference. Then each Visa APP/COM/ORG root was checked at 1280px/light, 320px/light and
  1280px/dark: **nine cases, all HTTP 200**. No horizontal overflow or page JavaScript errors;
  landing heading sizes were 36px desktop/30px mobile and the sign-in target height was at least
  49.1875px. Tab reaches the skip link first, Enter focuses main, and the next Tab reaches sign-in.
  Axe ran in all nine cases with **zero reported violations**. COM desktop light/dark and mobile
  screenshots were visually inspected. The first visual pass caught blue link text on a blue
  button; a landing-scoped foreground rule fixed it before the final nine-case run.
- Browser command: `bun tmp/visa-home-browser-check.mjs` (local temporary verification script).
  Browser requests were restricted to local hosts. Screenshots and raw results remained in `/tmp/`;
  no binary or raw-log evidence was added to the repository.

## Limits

The primary link's configured destination was checked, but browser sign-in was not submitted or
followed to the public Base service. External resources were blocked during the local browser
checks. Axe is an automated check, not a complete accessibility audit. The full suite and public
deployment were not run. This change introduces no custom keyboard handler; native link/skip-link
behavior was verified in Chromium. The Apple keyboard guide URL exposed only a JavaScript shell
through the web reader, and its Markdown alternative could not be fetched by that reader; the
repository's existing presentation and native-keyboard patterns were retained.
