# Publishing management UI (Base.Org CMS slice)

## Starting commit

`3bdc6bd0a008b51d80b4a1ff47592ee21bc59002` on `feature`

## Route surface

Base.Org host (`base.org` / `PUBLIC_BASE_STAFF_URL`). Resource hierarchy:

`/publishing/{info,docs,news,help}/{app,com,org}/entries`

Actions: `index`, `show`, `edit`, `update`. Identifier is `params[:id]` =
`Publishing::Entry#public_id`.

Helper pattern: `base_org_publishing_<surface>_<audience>_entries_path` and
`base_org_publishing_<surface>_<audience>_entry_path(public_id)`.

## Database invariant

`git diff -- db` was empty after this work.

No migrations, schema-support files, constraints, indexes, or columns were changed.

## Tests run

- `bin/rails test test/integration/routes/base_org_publishing_management_route_contract_test.rb` —
  pass
- `bin/rails test test/operations/publishing/revise_entry_operation_test.rb` — pass
- `bin/rails test test/controllers/base/org/publishing/entries_controller_test.rb` — pass
- `bin/rails test test/controllers/base/org/publishing/management_matrix_test.rb` — pass
- `bin/rails test test/unit/publishing_revision_content_digest_test.rb` — pass
- `bin/rails test test/unit/security/authentication_mode_inventory_test.rb` — pass
- `bin/rails test test/controllers/controller_inheritance_invariant_test.rb` — pass
- `bin/rails test test/models/publishing/schema_and_models_test.rb` — pass
- `pnpm exec vitest run spec/features/publishing/management_pages.test.tsx` — 3 passed
- `bundle exec rubocop` on modified Ruby files — no offenses
- `pnpm exec oxlint src/features/publishing spec/features/publishing src/pages/base/org/publishing`
  — 0 errors

`bin/rails test` (full suite): 12336 runs.

CMS-caused failures found and fixed:

- `test/unit/security/ri_routing_contract_test.rb` — 12 CMS controllers added to
  `RI_HTML_EXEMPT_CONTROLLERS` (bare CMS, locale is data not `ri`).
- `test/unit/security/public_entrypoint_inventory_test.rb` — new `PUBLIC_PUBLISHING_CMS` category
  documented in `docs/security/public-entrypoints.md`.

Those two files pass after the fix.

Remaining full-suite failures/errors observed, not attributed to this CMS change:

- `test/integration/fqdn_availability_gate_test.rb:190` — missing `base_app_health_livenesses_url`
- `test/integration/health_check_test.rb:87` — `/health` 404
- `test/integration/health_endpoints_test.rb:355` and `:373` — health 404 / wrong media type
- `test/integration/security_headers_test.rb:24` — missing `sign_app_health_livenesses_url`
- `test/config/host_authorization_contract_test.rb:126` — `jp.umaxica.dev` compose alias

First full run also failed Inertia digest/409 tests (`inertia_page_contract_test`,
`preference_inertia_page_contract_test`) after a Vite rebuild; they did not recur in the same way on
the second full run.

## Deployment gate

`base.org` or `/publishing/*` must actually be protected by Cloudflare Access before this
unauthenticated CMS is exposed externally. Rails authentication is intentionally absent. CSRF
remains enabled. This Access coverage was not verified in Rails and is not claimed by the accepted
Access ADR for `base.org`.
