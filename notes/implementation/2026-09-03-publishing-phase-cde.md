# Publishing Phase C–E implementation note

- Related: `adr/015-public-content-surfaces-astro.md` (Edge), Phase B publishing schema ADRs,
  `docs/reference/health-endpoints.md`.
- Date: 2026-09-03.

## Decisions

- Keep Rails `namespace` = content service (`info|docs|news|help`) and `surface` = audience
  (`app|com|org`). Edge Zod and cell filters follow that existing JSON, not the mission’s spoken
  “audience × surface” labels.
- Snapshot identity in JSON is `snapshot_public_id`. `version_public_id` was rejected by
  `PublishingEntryApiContractTest` (`/version/i` leak guard).
- Public hostname spelling (`docs.jp.umaxica.app` vs `docs.umaxica.app` vs Edge
  `docs-jp.umaxica.app`) remains configurable via `PUBLIC_REGION` / `CANONICAL_ORIGIN`. No new DNS
  convention was hard-coded.
- `/sitemap-dynamic.xml` is a valid empty `<urlset>` until a dedicated listing contract for sitemap
  rows exists. Index still references it.
- Worker cache is an overlay on 200 GET/HEAD `/[ja|en]/entries…` only. Health/revision stay
  no-store. Cache is not a correctness dependency.

## Deviations

- TanStack CMS paths were not deleted (rollback).
- RSS was not added.
- No production Cloudflare cutover (`wrangler.astro.jsonc` remains the Astro adapter configPath).

## Tests

- Rails: full suite 0 failures / 0 errors / 1 skip (seed 41217).
- Edge: 12 Astro builds; CMS Vitest; `astro:verify`; root matrix test.
