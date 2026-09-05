# Phase C1 — Publishing Entries API addressed by public_id

Date: 2026-09-03

## Scope

Changed the `GET /api/v0/entries/:id` show resource on all twelve publishing hosts (`{app,com,org}`
× `{info,docs,news,help}`) from slug-addressed to `public_id`-addressed, added `public_id` to the
entry representation, moved the OpenAPI 3.0.4 contract and bundles to match, and proved the edition
(audience/surface/locale cell) boundary on the new lookup. No Cloudflare / Workers VPC work; the
live Edge/VPC integration test is deferred.

## Changes performed

- Routes: `config/routes/{docs,help,info,news}.rb` —
  `resources :entries, only: %i(index show), param: :public_id` on all 12 host blocks.
  `bin/rails runner` route dump confirms
  `GET /api/v0/entries/:public_id => <service>/<surface>/api/v0/entries#show` for every host.
- `app/controllers/concerns/publishing_content_rendering.rb` — `render_publishing_entry_show` now
  `params.expect(:public_id)` → `publishing_entries_query.find_published(public_id:)`.
- `app/queries/publishing_published_entries_query.rb` — replaced `#find_by(slug:)` with
  `#find_published(public_id:)`, scoped to `edition.entries` (keeps the cell boundary), keeping the
  archived / active-publication guards.
- `app/serializers/publishing_entry_serializer.rb` — `public_id: entry.public_id` added as the first
  member; `slug` retained.
- OpenAPI: `openapi/shared/components.yml` (Entry: `public_id` added, required, documented opaque),
  `openapi/shared/paths/entry.yml` (path param `slug` → `public_id`), `openapi/{app,com,org}.yml`
  (path key `{slug}` → `{public_id}`). Bundles regenerated: `public/openapi.{app,com,org}.yml`.
  `pnpm run openapi:lint` → "API descriptions are valid".
- Regression guards updated deliberately: `test/config/routes_public_id_param_test.rb` and
  `test/config/acme_public_resource_routes_test.rb` now exempt the four content route files, with a
  comment recording that Phase C1 makes `public_id` a genuine API-contract path parameter for
  entries (distinct from the Acme account/organization convention in
  adr/acme-account-organization-resource-boundary.md, which keeps `params[:id]` + `to_param`).

## Response schema (show body / each `data[]` element)

`public_id, namespace, surface, slug, locale, title, summary, body, published_at, taxonomy` — exact
key set pinned by `PublishingEntryApiContractTest`. Collection envelope unchanged:
`{ data: [...], page: { next_cursor, has_more } }`.

## Verification

Targeted run (2026-09-03), all green:

```
bin/rails test \
  test/contracts/openapi_content_entries_contract_test.rb \
  test/contracts/publishing_entry_api_contract_test.rb \
  test/queries/publishing_published_entries_query_test.rb \
  test/config/routes_public_id_param_test.rb \
  test/config/acme_public_resource_routes_test.rb \
  test/controllers/help_docs_news_surface_smoke_test.rb \
  test/controllers/info_surface_publishing_test.rb \
  test/integration/read_only_surfaces_test.rb \
  test/contracts/openapi_route_coverage_test.rb \
  test/integration/routes/{docs,help,news,info}_route_contract_test.rb \
  test/integration/content_surface_boundary_test.rb
=> 110 runs, 986 assertions, 0 failures, 0 errors, 0 skips
```

`test/queries/publishing_published_entries_query_test.rb` alone: 14 runs, 39 assertions, 0 failures.
`test/contracts/openapi_content_entries_contract_test.rb` alone: 37 runs, 0 failures (covers all
twelve service/surface combinations for index and show, plus new cross-cell isolation and
draft/archived-by-public_id tests).

Coverage added: valid public_id → entry; unknown public_id → 404 `application/problem+json`; DB
primary key rejected; slug rejected as `:public_id`; app/docs public_id returns 404 through
com/docs, org/docs, app/help, app/news, app/info and through app/docs in another locale; draft and
archived not readable by known public_id; `data[].public_id` present on the index; `find_published`
unit cases for wrong-edition / draft / archived / pk-string.

## Full suite

`bin/rails test test/` (2026-09-03): 12255 runs, 8 failures, 3 errors before the guard-test fixes;
after fixing `routes_public_id_param_test` and `help_docs_news_surface_smoke_test` the remaining 6
failures + 3 errors are all pre-existing branch work unrelated to Phase C1: the in-progress
`base/*/api/v0/healths` + `dbsc_controller` edge-health refactor (`forbidden_rails_patterns_test`,
`ri_routing_contract_test`, `controller_inheritance_invariant_test`, `bare_controller_test`,
`public_entrypoint_inventory_test`, `html_title_contract_test`, `DbscControllerTest`) and a missing
`compose.override.yaml.example` (`compose_local_override_optional_test`). Confirmed these fail
independently of the Phase C1 changes.

## Deferred

- Live Cloudflare Workers VPC / Edge integration test — VPC unavailable; no Cloudflare configuration
  touched. Run once the Edge consumer and VPC egress are restored.
- Edge (`fetchAllEntries()` etc.) implementation — not started from this repository.
