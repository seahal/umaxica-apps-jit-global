# Visa public roots

Revision: `bde2346c17e2aa911acc95de1f6035f80498f2da`, with extensive pre-existing uncommitted
work and this uncommitted root change.

Added `root "roots#index"` within the existing Visa realm host scopes, three generated
surface-local RootsControllers inheriting their own BareController, and three standalone ERB
landing documents. The page titles and headings are the surface proper names. Existing CSS is
reused. No sign-in workflow, session issuance, database schema or cross-surface view is introduced.
The routing exception is recorded in `adr/rails-routing-resourceful-policy.md`; the UI inventory
now records these ERB roots alongside Visa's existing Inertia protocol pages.

## Verification

- Red: `bin/rails test test/integration/visa_roots_test.rb`: two tests, seven assertions,
  one expected failure (`404 unknown_host` instead of `200`).
- Green: `bin/rails test test/integration/visa_roots_test.rb
  test/integration/unknown_host_root_test.rb test/controllers/controller_base_inheritance_test.rb
  test/unit/security/authentication_mode_inventory_test.rb`: 23 tests, 338 assertions,
  no failures/errors/skips. Public APP/COM/ORG and localhost roots render their own HTML;
  HEAD is empty, no Set-Cookie header is emitted, no-store applies, and look-alike hosts remain 404.
- A broader run also included `test/controllers/controller_inheritance_invariant_test.rb`:
  25 tests, 344 assertions, one failure, no errors/skips. The failure lists eight existing Visa
  OIDC cancellation/result/switch controllers inheriting other concrete controllers; none is a new
  RootsController. Those files and the guard were left unchanged.
- RuboCop on the three new controllers and the request test: four files, no offenses.
- ERB lint on the three new views: no errors. The tool emitted its Ruby parser-version warning.
- Scoped whitespace verification passed.

Browser tooling is unavailable in this session, so visual/responsive browser verification was not
performed. The full suite was not run. No deployment or external change was performed.
