# Docs, Help, And News Content Boundary

## Purpose

This document describes the current responsibility split for `docs`, `help`, and `news`.

> **Persistence (2026-07-16, cutover complete):** Per `adr/publishing-db-content-authority.md`, the
> content authority for `info`, `docs`, `news`, and `help` lives in the central `publishing`
> database (`Publishing::Entry` / `EntryRevision` / `EntryVersion` / `Publication` and media
> tables). All four surfaces are global content surfaces; `app`/`com`/`org` are audience
> identifiers. The legacy lean content-entry and CMS tables have been dropped from the zenith
> databases in development and test; production requires a separately approved migration run.

## Frontend Ownership

Edge owns the public frontend for `docs`, `help`, `news`, `info`, and `core`. Current Edge runtime
is TanStack Start on Cloudflare Workers. An Astro migration for the twelve content units is
accepted in Edge `adr/015` but is not deployed. Historical Rails ADRs that name Next.js remain
history.

The twelve audience × surface cells are listed in `docs/architecture/content-surface-matrix.md`.

Edge owns, when those pages are implemented:

- public HTML;
- article index pages;
- article show pages;
- SEO metadata;
- canonical URLs;
- `robots.txt`;
- `sitemap.xml`;
- UI and UX;
- public 404 and 410 rendering;
- locale fallback rendering when needed.

**Current CMS integration status:** Rails exposes the read API. Edge does not yet consume
`/api/v0/entries` for list or detail pages. Do not describe Edge CMS pages as deployed.

Hono may remain for bounded uses such as jump behavior. It does not own public article HTML.

## Rails Ownership

Rails owns the content authority and read contract for `docs`, `help`, and `news`.

Rails owns:

- host-constrained surface routing;
- thin root endpoints;
- health endpoints;
- read-only content persistence;
- import tasks;
- read-only `api/v0/entries` contracts intended for Edge consumption (not yet wired in Edge).

Rails must not own public article HTML rendering for these surfaces. Rails root endpoints may
remain, but they must stay thin and must not render article indexes, article detail pages, SEO
metadata, canonical URLs, `robots.txt`, or `sitemap.xml`.

## Routing Direction

Do not collapse `docs`, `help`, and `news` into a single host or a single API host with a surface
path segment. Keep the existing host-constrained routing model, with separation by host, namespace,
and surface.

Rails should conceptually keep:

```text
GET /
GET /health              # text/plain aggregate
GET /health/liveness     # text/plain probe
GET /health/readiness
GET /health/startup
GET /api/v0/health.json   # application/json machine health
GET /api/v0/revision.json
GET /api/v0/entries
GET /api/v0/entries/:slug
```

The same route shape applies independently under each docs, help, and news app/com/org host.

The API resource noun is `entries`, not `posts`. `posts` implies blog, SNS, or forum-style posting
and may conflict with other Umaxica post domains. Help entries are help article/content reads; they
are not Contact or inquiry workflow.

Do not adopt a single API host or surface path segment. These shapes are not the target:

```text
/api/v0/docs/entries
/api/v0/news/entries
/api/v0/help/entries
/api/v0/content/docs/entries
```

Rails should not own:

- `/entries`;
- `/entries/:slug`;
- `/robots.txt`;
- `/sitemap.xml`;
- `/auth/callback`;
- `/web/v0/cookie`;
- `/web/v0/theme`;
- mutation routes;
- dedicated taxonomy routes (taxonomy is a field on an entry and a filter parameter on the index,
  never its own resource);
- revision or version routes.

Do not add placeholder routes, controllers, response contracts, or schemas for excluded future work.

## Controller Boundary

`docs`, `help`, and `news` Rails controllers must not create identity, session, authorization,
preference, or OIDC authority.

For the current read-only public contract, use the surface-local `BareController` tier or an
equivalent API-only base that does not depend on:

- `ApplicationController`;
- authentication concerns;
- authorization concerns;
- Pundit or Action Policy user context;
- `Current` or `Actor`;
- Rails sessions;
- preference cookies or preference writes;
- OIDC callbacks.

`app` and `com` content reads are public by default. `org` content reads may become authenticated or
org-scoped in the future, but that must reuse the existing authority boundary and must not make
`docs`, `help`, or `news` a new identity, session, or authorization authority.

## Persistence Direction

Content persistence lives in the central `publishing` database. Controllers read through
`PublishingContentRendering`, which resolves an edition by explicit per-controller
`PUBLISHING_AUDIENCE` / `PUBLISHING_SURFACE` constants — never dynamically from a class name or
request parameter.

A serialized entry carries exactly these keys, pinned by
`test/contracts/publishing_entry_api_contract_test.rb`:

```text
namespace  surface  slug  locale  title  summary  body  published_at  taxonomy
```

`namespace` carries the content surface (`docs`/`news`/`help`/`info`) and `surface` carries the
audience (`app`/`com`/`org`). `body` is always the complete JSON object.

Taxonomy is decided in `adr/publishing-taxonomy-architecture.md`. Each entry exposes
`taxonomy.category` (one object with its breadcrumb `path`, or `null`) and `taxonomy.tag` (an ordered
array), rendered from the published version's frozen snapshots rather than from the current draft or
from current term names. The index accepts `?category=<slug>` and `?tag=<slug>`.

Authoring UI, approval workflow, and any write endpoint remain out of scope for these surfaces.

Mutation belongs to future base > org authoring or management work. Docs, help, and news remain
read-only surfaces.

## Related

- `adr/publishing-db-content-authority.md`
- `adr/publishing-taxonomy-architecture.md`
- `docs/architecture/content-surface-matrix.md`
- `docs/architecture/publishing-persistence.md`
- `adr/publishing-persistence-polymorphism-prohibition.md`
- `docs/architecture/regional-content.md`
- `docs/architecture/acme-sign-core-base-port.md`
