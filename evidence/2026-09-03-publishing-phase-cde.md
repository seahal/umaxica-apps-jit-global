# Publishing Phase C–E implementation evidence (2026-09-03)

Record of work actually performed. Not a plan.

## Phase B gate

- `HtmlTitleContractTest` now allowlists `GET /health` as a non-HTML `text/plain` probe. Health was
  not reverted to HTML.
- `/api/v0/health.json`, `/revision`, `/api/v0/revision.json` were not changed in this pass.
- Full Rails suite: `bin/rails test` seed `41217`.
  - 12207 runs, 66482 assertions, **0 failures, 0 errors, 1 skip**.
- `evidence/2026-09-03-publishing-media-usage-split.md` was rewritten to the final Phase B schema
  (owner-explicit usage tables, no INSERT…SELECT union table).

## Phase C (Rails)

- Public entry JSON gained `updated_at`, `public_id`, `snapshot_public_id` (not `version_public_id`;
  that name failed the no-identifier-leak contract).
- OpenAPI `Entry` required list updated in `openapi/shared/components.yml` and bundled to
  `public/openapi.{app,com,org}.yml`.
- Development seeds publish `welcome` via edition → revision → `PromoteRevisionOperation` →
  publication for 3×4×ja/en.

## Phase C–E (Edge, `/tmp/umaxica-apps-edge`)

- All twelve Astro units (`app|com|org` × `info|docs|news|help`) gained on-demand `/[lang]/entries`
  list/detail (`prerender = false`), Zod runtime schema, VPC `getRailsClient` fetch, generic outward
  5xx, `Cache-Control: no-store` on CMS fetch paths before Phase D cache overlay.
- 12× `astro:build` succeeded with `output: "static"`; entries routes stayed off the prerender list.
- 12× CMS Vitest files (schema/fetch/validators) passed; later cache/security tests passed on
  `app/docs` and were copied to the matrix.
- JS-disabled SEO verify (`astro:verify`) passed for all 12 units (FAILFLAG=0) against prerendered
  pages.
- Root `test/cms-astro-matrix.test.ts`: 13 tests passed.
- Phase D: sitemap-index / sitemap-0 / sitemap-dynamic (dynamic stub empty urlset), robots
  `Sitemap: …/sitemap-index.xml`, HTML ETag + Last-Modified helpers, Workers Cache for
  locale-prefixed `/entries` only (TTL 300 info/news, 1800 help/docs), centralized
  `astroSecurityHeaders()`.
- Phase E: structured `console.info` JSON from `cms-fetch` with audience/surface/locale/slug/class
  only. No document body.

## Production actions not performed

- No production deploy.
- No Cloudflare dashboard/account mutation.
- No production database mutation.

## Measured vs inferred

- Measured: Rails full suite green; 12 Astro builds; unit Vitest; SEO verify on static HTML.
- Not measured: production TTFB, VPC latency, cache hit ratio, live crawler behavior.
