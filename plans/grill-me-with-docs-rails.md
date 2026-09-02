# Grill me with docs: Rails content authority for Astro

## Status

Implementation prompt / working plan for `seahal/umaxica-apps-jit-global`.

This is the Rails half of the public-content migration. The paired Edge plan lives in
`seahal/umaxica-apps-edge` on `plan/grill-me-with-docs-astro`.

**Rails owns content authority and machine contracts. Astro owns public HTML, canonical URLs,
hreflang, robots, sitemap XML, and presentation.** Do not implement Astro code in this repository.

## Start by treating the repository as source of truth

Read `AGENTS.md` and all task-specific rules it names before editing, especially:

- `.agents/harnesses/rules/generic/controllers.mdc`
- `.agents/harnesses/rules/generic/routing.mdc`
- `.agents/harnesses/rules/generic/data-shape-design.mdc`
- `.agents/harnesses/rules/project/surfaces.mdc`
- `.agents/harnesses/rules/project/controller-inheritance.mdc`
- `.agents/harnesses/rules/project/value-object-boundaries.mdc`
- `docs/reference/api-design-standards.md`
- `adr/api-versioning-and-client-conventions.md`
- `adr/api-error-format-problem-details.md`
- `adr/api-collection-contract.md`
- `adr/publishing-db-content-authority.md`
- `docs/architecture/docs-help-news-content-boundary.md`

Inspect the live implementation before changing anything:

- `config/routes/{info,docs,help,news}.rb`
- all 12 `{surface}/{audience}/api/v0/entries_controller.rb`
- `PublishingContentRendering`
- `PublishingPublishedEntriesQuery`
- `PublishingEditionResolver`
- `PublishingEntrySerializer`
- `Publishing::Entry`
- `Publishing::EntrySlug`
- `Publishing::EntryVersion`
- `Publishing::Publication`
- OpenAPI source/bundles and contract tests

Do not revive the old lean per-surface content tables. The central `publishing` database is the
current authority.

## Current facts to preserve

The repository already has the correct high-level content model:

```text
Publishing::Edition
  audience = app | com | org
  surface  = info | docs | help | news
  locale

Publishing::Entry
  -> EntrySlug
  -> EntryRevision
  -> immutable EntryVersion
  -> Publication
```

The public read path already exists for all 12 surface/audience combinations under host-constrained
`/api/v0/entries` routes.

The current v0 serializer returns:

```json
{
  "namespace": "docs",
  "surface": "com",
  "slug": "example",
  "locale": "ja",
  "title": "...",
  "summary": "...",
  "body": {},
  "published_at": "...",
  "taxonomy": {}
}
```

The current query already hides drafts/unpublished rows and uses the active publication. The current
rendering concern already provides bounded cursor pagination, RFC 9457 errors, ETag, Last-Modified,
and short public cache metadata.

Build on these pieces. Do not invent a parallel CMS stack.

## Primary goal

Create a stable **`/api/v1` public read contract** suitable for Astro SSR.

`v1` is not a cosmetic namespace change. Per `adr/api-versioning-and-client-conventions.md`, declaring
v1 means the response/status contract becomes frozen under the repository's compatibility policy.

Therefore:

1. do not remove v0 in the same implementation slice;
2. add v1 in parallel;
3. migrate the Astro consumer to v1;
4. retire v0 only in a later explicitly coordinated change.

## Mandatory API-shape approval gate

`generic/data-shape-design.mdc` applies. **Before editing any serializer/controller/OpenAPI file that
changes or introduces the v1 response shape, stop and present a Before/After proposal to the user.**
Do not proceed until explicitly approved.

Use the current v0 object as `Before`.

Recommended candidate `After` for discussion only:

```json
{
  "id": "<entry-public-id>",
  "surface": "docs",
  "audience": "com",
  "slug": "example",
  "locale": "ja",
  "title": "...",
  "summary": "...",
  "body": {},
  "published_at": "...",
  "updated_at": "...",
  "version": "<entry-version-public-id>",
  "taxonomy": {}
}
```

Rationale for the candidate:

- `id` exposes the existing public entry identity, never the database PK.
- `surface` means `info/docs/help/news`.
- `audience` means `app/com/org`.
- This removes the v0 legacy ambiguity where `namespace` means surface and `surface` means audience.
- `version` must identify the immutable **published `EntryVersion`**, not `EntryRevision`; revision is
  mutable editorial history and must not be exposed as the public representation marker.
- `updated_at` must describe the public representation's last meaningful change. Do not blindly
  serialize an Active Record row's `updated_at`; derive and document the authoritative instant from
  the active publication/version semantics.

If investigation establishes a better shape, propose it instead. The approval gate still applies.

## Astro/Rails responsibility boundary

Rails returns content facts only. It must not return or own:

- absolute canonical Web URLs;
- hreflang URLs;
- final browser redirect URLs;
- robots.txt;
- sitemap XML;
- public HTML;
- Astro layout choices;
- OG images;
- JSON-LD.

Astro derives presentation URLs from TLD, locale, region, and routing.

Rails may return canonical **slug/identity** facts needed for Astro to build those URLs.

## v1 entry show lifecycle semantics

The existing v0 `find_by(slug:)` deliberately only resolves canonical, currently published entries;
that is insufficient for CMS-grade public HTTP semantics because it collapses redirects, archived
content, unpublished content, and unknown slugs into one absence.

Add a dedicated read-side resolver/query for v1 rather than putting lifecycle logic in controllers.
It should distinguish at least:

```text
current
redirect
explicitly gone
not publicly resolvable
```

Use existing authoritative state:

- `Publishing::EntrySlug.state` (`canonical`, `redirect`, `reserved`)
- `Publishing::Entry.archived_at`
- active publication presence
- canonical slug association

Required public semantics:

```text
canonical slug + active publication + not archived -> 200
redirect slug whose entry has a valid canonical target -> permanent 3xx
explicitly archived/withdrawn canonical resource with no replacement -> 410
unknown slug -> 404
reserved/draft/scheduled/unpublished resource -> 404, not 410
```

Do not disclose the existence of drafts or reserved slugs through a different public error.

The exact permanent redirect code (301 vs 308) and the v1 machine redirect representation/header
are part of the API-shape/status contract. Present them in the approval proposal before implementation.

Rails must not construct an absolute Astro URL. If the API uses `Location`, keep it API-relative or
otherwise return only the target canonical slug/identity so Astro can construct the public URL.

## 410 semantics

Do not infer `410 Gone` merely because no publication is active.

`410` is for an explicitly retired/archived public resource. A draft, future publication, expired
publication that may return, or otherwise non-public resource should remain indistinguishable from
unknown content unless a current domain decision says it is permanently withdrawn.

If the existing archive model cannot safely distinguish permanent withdrawal from other archive
reasons, report that as a domain gap before changing status behavior.

## Stable version and updated time

Expose a stable public marker derived from the immutable `Publishing::EntryVersion`.

Prefer its `public_id`; do not expose the database ID and do not call an `EntryRevision` identifier a
public version.

Define one authoritative `updated_at` semantic for v1. Candidate for discussion:

```text
public representation updated_at = instant when the active published representation became effective
```

That likely derives from `Publishing::Publication#effective_from`, possibly combined with the
immutable version timestamp if investigation shows a case where publication time alone is wrong.

The definition must be documented and tested because Astro will use it for:

- HTML `Last-Modified`;
- dynamic sitemap `<lastmod>`.

## Conditional requests

Preserve and strengthen the existing HTTP validator behavior.

Rails v1 should continue to support:

- ETag;
- Last-Modified;
- `If-None-Match`;
- `If-Modified-Since`;
- `304 Not Modified`.

The Rails ETag is for the **JSON API representation**. Astro must generate its own HTML ETag; do not
try to make one validator serve both representations.

Prefer validators computed from the actual rendered v1 payload or an equivalent deterministic
representation marker so response content and validator cannot drift.

## Rails cache behavior

Do not introduce a new cache store, purge protocol, tag invalidation, or deployment-time purge
workflow in this task.

The first Astro integration must be correct when Astro calls Rails on every request.

Existing Rails conditional response/cache headers may remain if semantically correct, but do not make
correctness depend on an intermediary cache hit. The Edge team will introduce Workers Cache later with
a short TTL and natural expiry.

## Collection endpoint

Keep the accepted collection contract:

```json
{
  "data": [],
  "page": {
    "next_cursor": null,
    "has_more": false
  }
}
```

Keep cursor pagination bounded. Do not restore unbounded index responses or offset pagination.

Do not return full collections solely so Astro can build a sitemap if that requires transferring every
entry body.

## Sitemap feed for Astro

Astro will generate `/sitemap-dynamic.xml`, but it needs a lightweight Rails listing of published
content facts.

Investigate whether the existing paginated entries endpoint can satisfy this without downloading full
`body`/taxonomy payloads. It probably should not be abused for this if the payload is large.

If a dedicated lightweight listing endpoint is justified, propose its route and shape under the
mandatory data-shape approval gate before implementation.

It should expose only facts Astro needs, such as:

```text
entry public identity
canonical slug
locale / edition scope
public updated_at
```

Do not return absolute canonical Web URLs or sitemap XML from Rails.

The endpoint must be bounded/paginated if the set can grow without bound.

## Search: planned, not implemented in this slice

Search is intentionally a separate future contract.

Direction already decided:

```text
Browser
  -> public versioned Rails API (/api/v1/...)
  -> Rails search
  -> JSON results
```

Astro must not proxy browser search requests.

Known product constraints:

- `info` uses a global search scope;
- `docs`, `help`, and `news` use local search scopes;
- multiple TLD/surface entry points will exist;
- the search API is versioned under v1.

Not yet decided:

- exact endpoint count;
- exact host/path matrix;
- query request shape;
- pagination;
- ranking;
- full-text engine/index technology;
- controller/query/service boundaries;
- CORS policy;
- search-specific rate limits.

Do not implement placeholder search routes, controllers, empty responses, database columns, indexes,
or OpenAPI operations in this task. Record a TODO/plan only.

## Browser-direct API security for future search

When search is implemented later, it will be browser-visible unlike the Astro->Rails VPC document
read path. That later task must explicitly design:

- allowed public origins / CORS;
- rate limiting;
- abuse controls;
- cache policy;
- query length/complexity bounds;
- logging/redaction;
- CSP coordination with Astro.

Do not pre-implement these now.

## Surface isolation

Preserve host-constrained surface routing and the existing `app`, `com`, `org` trust boundaries.

Do not collapse the four content surfaces into one generic public host or permit a request parameter
to choose audience/surface dynamically.

The controller namespace/host determines:

```text
PUBLISHING_AUDIENCE
PUBLISHING_SURFACE
```

Keep that explicit model.

## Controller design

Controllers remain HTTP-only and thin.

Do not put lifecycle resolution, search, serializer branching, or sitemap listing logic directly into
controllers. Use the repository's established query/resolver/serializer/value-object placement rules.

Keep the public content controllers on the bare/API-only inheritance path. Do not introduce session,
OIDC, preference, actor, or authenticated Core authority into these endpoints.

## Errors and disclosure

Keep RFC 9457 Problem Details for v1 errors.

Public responses must not reveal:

- whether a hidden draft exists;
- archive reasons unless explicitly made public by contract;
- database identifiers;
- storage paths/S3 keys;
- internal hostnames;
- stack traces;
- exception messages;
- authorization/cookie/token material.

Internally, distinguish outcomes in structured logs/telemetry without logging content bodies or raw
parameters.

## Object storage boundary

Astro must not know S3 details.

If the publishing body references media/assets, Rails may resolve or serialize public asset references
according to the existing publishing/media model, but do not expose storage bucket names, internal
object keys, credentials, or backend topology merely for Astro convenience.

If no safe public asset-reference contract exists, report the gap rather than inventing one in a
controller.

## OpenAPI

Add v1 operations to the existing OpenAPI 3.0.4 source tree and generated per-audience bundles.

Requirements already established by ADRs remain binding:

- actual routes and actual hosts only;
- RFC 9457 errors by reference;
- no internal hostnames;
- clients tolerate additive unknown fields;
- committee request/response validation;
- bundle drift checks;
- route/OpenAPI bidirectional coverage.

Do not delete the v0 description while v0 remains routed.

## Testing

Use Minitest and the repository's existing contract layers.

At minimum cover:

### Resolver/query tests

- canonical published entry -> current result;
- redirect slug -> redirect result and canonical target;
- archived explicit withdrawal -> gone result;
- draft/reserved/unpublished -> not found result;
- unknown slug -> not found result;
- audience/surface/locale isolation;
- no cross-surface leakage.

### Serializer/value tests

After the v1 shape is approved:

- exact required key/type contract;
- public IDs only;
- immutable published version marker;
- deterministic `updated_at` semantic;
- body remains structured JSON;
- taxonomy remains a published-version snapshot.

### Controller/integration tests

- 200 current entry;
- permanent 3xx redirect contract;
- 404 unknown/hidden;
- 410 gone;
- RFC 9457 media type and shape;
- ETag;
- Last-Modified;
- 304 for matching validators;
- bounded index pagination;
- malformed cursor/limit behavior unchanged;
- sitemap-feed endpoint if approved;
- correct host constraints for all 12 combinations.

### OpenAPI contract tests

- request/response validation for every v1 operation;
- all v1 Rails routes are documented;
- every documented route exists;
- v0 remains documented until separately retired.

## Migration order

Recommended implementation sequence:

1. Read applicable AGENTS/rules/ADRs and inspect live code.
2. Record any conflict between this plan and current accepted ADRs/code.
3. Present the mandatory Before/After v1 shape + status proposal and wait for approval.
4. Add v1 routing/controllers in parallel with v0 for one representative surface/audience.
5. Implement the lifecycle resolver and v1 serializer without changing v0 behavior.
6. Prove 200/redirect/404/410 and validators with focused tests.
7. Add/validate OpenAPI v1 for that vertical slice.
8. Replicate the proven controller wiring across the other 11 host-constrained combinations.
9. Add the lightweight sitemap data endpoint only if separately justified and shape-approved.
10. Run focused tests, then the risk-appropriate broader suite.
11. Leave search as a documented future task.

Do not deploy, run destructive publishing migrations, mutate Cloudflare resources, or remove v0 without
explicit authorization.

## Acceptance criteria

This Rails slice is complete when:

- central `publishing` DB remains the sole content authority;
- all four surfaces × three audiences have a parallel v1 public read contract;
- v0 remains available and behaviorally unchanged unless separately approved;
- v1 API shape was explicitly approved before implementation;
- Astro can fetch one canonical published document entirely server-side;
- redirect slugs, gone content, hidden/unpublished content, and unknown slugs are distinguishable with
  the approved HTTP semantics;
- no hidden draft existence is disclosed;
- v1 exposes a stable immutable public version marker;
- v1 exposes a documented public `updated_at` semantic suitable for Astro Last-Modified/sitemap;
- ETag/Last-Modified/304 are tested;
- collection pagination remains bounded/cursor-based;
- a lightweight sitemap listing exists only if justified and approved;
- Rails returns content facts, never final canonical/hreflang Web URLs or sitemap XML;
- OpenAPI 3.0.4 and Committee coverage are current;
- search remains deferred, with no placeholder implementation;
- focused tests and the required broader verification are green.
