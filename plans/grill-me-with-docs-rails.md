# Grill me with docs: Rails content authority for Astro

## Status

Implementation prompt / working plan for `seahal/umaxica-apps-jit-global`.

This is the Rails half of the public-content migration. The paired Edge/Astro plan lives in
`seahal/umaxica-apps-edge`.

**Rails owns content authority and machine-readable data. Astro owns public HTML, canonical URLs,
hreflang, robots, sitemap XML, and presentation.** Do not implement Astro code in this repository.

## API versioning decision for this task

Use the existing **`/api/v0`** namespace.

Do **not** create `/api/v1` for this work.

In this repository, `v0` intentionally means the first-party/internal-facing contract is still free to
evolve. It is not a promise of long-term compatibility. This Astro integration remains part of that
changing private/first-party contract.

Therefore:

- extend/refine the existing `/api/v0/entries` contract where necessary;
- do not duplicate the same content API under v1;
- do not add compatibility shims merely to preserve the current v0 shape unless a real current
  consumer requires them;
- coordinate any actual shape change with the Astro implementation in the same development effort;
- reserve v1 for a future deliberate contract-freeze decision.

`adr/api-versioning-and-client-conventions.md` remains authoritative: v0 is unfrozen; v1 would be a
separate deliberate commitment and is explicitly out of scope here.

## Start from the repository, not this prompt

Read `AGENTS.md` and the task-specific rules it names before editing, especially:

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

## Current architecture to preserve

The repository already has the correct high-level model:

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

The current serializer shape is approximately:

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

The current implementation already provides:

- central Publishing DB reads;
- currently published entry filtering;
- bounded cursor pagination;
- RFC 9457 Problem Details;
- ETag / Last-Modified / 304 support;
- host-constrained audience/surface isolation;
- taxonomy snapshots from the published version.

Build on this. Do not invent a second CMS stack.

## Mandatory data-shape approval gate

`generic/data-shape-design.mdc` still applies even though v0 is intentionally mutable.

Before changing the API response shape, present a concise **Before / After** proposal to the user and
wait for explicit approval.

The fact that v0 is unfrozen means compatibility is not promised; it does **not** mean shape changes
may bypass the repository's data-shape review rule.

A likely candidate for discussion is:

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

This is a proposal, not authorization to implement it unchanged.

Points to examine:

- whether to remove the legacy ambiguity where `namespace` means content surface and `surface` means
  audience;
- whether `id` should expose the existing entry `public_id`;
- whether `version` should expose the immutable published `EntryVersion#public_id`;
- what `updated_at` means for a public representation.

Never expose database primary keys.

## Rails/Astro responsibility boundary

Rails returns content facts. Rails must not own or return final presentation concerns such as:

- absolute canonical Web URL;
- hreflang URLs;
- public HTML;
- robots.txt;
- sitemap XML;
- Astro route decisions;
- OG images;
- JSON-LD.

Astro knows the final TLD, locale/region routing, and public URL model, so Astro owns the Web
representation.

Rails may return canonical slug/identity and locale/audience/surface facts needed to construct those
URLs.

## Entry lifecycle semantics

The existing v0 read path currently resolves only canonical, currently published content. For the new
Astro CMS-like rendering path, investigate and implement a dedicated read-side lifecycle resolver so
Rails can distinguish public states without leaking private editorial state.

Use authoritative existing state where possible:

- `Publishing::EntrySlug.state` (`canonical`, `redirect`, `reserved`);
- `Publishing::Entry.archived_at`;
- active publication presence;
- canonical slug association.

Target semantics:

```text
canonical + active publication + not archived
  -> current document

redirect slug with a valid canonical target
  -> moved document

explicitly retired/withdrawn previously-public document with no replacement
  -> gone

unknown slug
  -> not found

reserved / draft / scheduled / unpublished
  -> not found
```

Do not disclose draft/reserved existence through distinct public responses.

### 3xx

Astro ultimately owns the browser redirect URL, so Rails should preferably return the canonical target
slug/identity rather than build an absolute Web URL.

If an HTTP redirect is used at the Rails API layer, define its semantics explicitly and validate that
it cannot become an open redirect. Decide 301 vs 308 as part of the shape/status proposal rather than
by accident.

### 410

Do not infer `410 Gone` merely because no publication is currently active.

410 is appropriate only when the domain can say the formerly-public resource has been intentionally
withdrawn permanently enough to expose that fact.

Draft, reserved, future, temporarily unpublished, or otherwise hidden content remains 404-equivalent.

If the current archive model cannot distinguish permanent public withdrawal from other archive
reasons, report that domain gap before implementing 410 behavior.

## Public version marker

A public representation marker should come from immutable `Publishing::EntryVersion`, not from an
editable `EntryRevision`.

Prefer an existing public ID. Do not expose database IDs.

This marker is useful to Astro for deterministic HTML representation handling, but Rails' JSON ETag
and Astro's HTML ETag remain different validators for different representations.

## updated_at semantics

Add or expose an authoritative public modification instant suitable for Astro:

```text
Astro HTML Last-Modified
sitemap <lastmod>
```

Do not blindly serialize whichever Active Record row happened to be touched last.

Investigate the publishing semantics and document one stable definition. A plausible candidate is the
instant the active published representation became effective (`Publication#effective_from`), but use
the actual domain model as source of truth.

The chosen meaning must be tested.

## Conditional HTTP requests

Preserve the current good behavior:

- ETag;
- Last-Modified;
- `If-None-Match`;
- `If-Modified-Since`;
- `304 Not Modified`.

Rails' ETag describes the JSON representation only.

Prefer validators computed from the actual serialized payload or an equivalent deterministic
representation marker so they cannot drift from response content.

## Cache behavior

Do not add a new Rails cache store, purge protocol, tag invalidation system, or deployment-time purge
workflow for this task.

The first Astro integration must work correctly when every Astro request reaches Rails.

Existing Rails HTTP cache metadata may remain if correct, but correctness must not depend on a cache
hit.

Workers Cache is an Edge/Astro optimization to be added later with short TTL and natural expiry.

## Collection endpoint

Keep the accepted bounded cursor pagination contract unless the user explicitly approves a change:

```json
{
  "data": [],
  "page": {
    "next_cursor": null,
    "has_more": false
  }
}
```

Do not restore unbounded collection responses.
Do not add offset pagination.

## Sitemap data feed for Astro

Astro will own `/sitemap-dynamic.xml`, but Rails must expose enough machine-readable published content
facts to generate it.

First investigate whether the existing `/api/v0/entries` index can serve this efficiently. Do not
force Astro to download every document `body` and taxonomy solely to obtain sitemap metadata.

If a dedicated lightweight endpoint is justified, propose its route and response shape through the
mandatory Before/After approval gate before implementation.

It should contain only facts such as:

```text
entry public identity
canonical slug
locale / audience / surface
public updated_at
```

Do not return sitemap XML.
Do not return final absolute Web canonical URLs.
Do not return storage information.

Any potentially unbounded listing must remain paginated/bounded.

## Search: future v0 API, not implemented now

Search is intentionally separate from Astro SSR document retrieval.

The direction is:

```text
Browser
  -> Rails public/first-party API under /api/v0/...
  -> search implementation
  -> JSON
```

Do not use `/api/v1` for search in this design.

The same API versioning philosophy applies: search remains an evolving first-party/internal contract
under v0 until a future explicit freeze decision.

Known requirements only:

- `info` uses global search;
- `docs`, `help`, `news` use local search;
- multiple TLD/surface entry points will exist;
- browser calls Rails directly rather than through Astro.

Still undecided:

- exact number of endpoints;
- host/path matrix;
- request query shape;
- pagination;
- ranking;
- search engine/index technology;
- Rails controller/query/service split;
- CORS;
- rate limits;
- abuse policy.

Do not create placeholder routes, empty controllers, fake JSON responses, search tables, indexes, or
OpenAPI operations yet.

## Future browser-direct search security

Because search will be browser-visible, the later search task must explicitly design:

- CORS / allowed origins;
- rate limiting;
- abuse controls;
- query size/complexity limits;
- cache policy;
- log redaction;
- CSP coordination with Astro.

Do not pre-implement those concerns here.

## Surface isolation

Preserve host-constrained routing and the `app`, `com`, `org` boundaries.

Do not collapse `info/docs/help/news` into one generic host selected by request parameters.

Audience and publishing surface remain explicit controller constants derived from the host/namespace:

```text
PUBLISHING_AUDIENCE
PUBLISHING_SURFACE
```

Do not allow callers to select them arbitrarily via JSON/query input.

## Controller boundary

Controllers remain HTTP-only and thin.

Lifecycle resolution, serialization, listing, and future search logic belong in the established
query/resolver/serializer/value-object layers according to repository rules.

Keep these public content APIs on the bare/API-only controller path. Do not add:

- Rails session authority;
- OIDC flows;
- user preferences;
- Actor/Current state;
- authenticated Core behavior.

## Error format and disclosure

Keep RFC 9457 Problem Details for API errors.

Do not reveal:

- hidden draft existence;
- reserved slug existence;
- archive/internal moderation reasons unless explicitly approved as public data;
- database IDs;
- S3/object-storage internals;
- internal hostnames;
- stack traces;
- exception messages;
- cookies/tokens/secrets.

Internal logs may classify outcomes, but must not log content bodies or arbitrary request parameters.

## Object storage boundary

Rails may use S3 or another object store internally, but Astro must not know that topology.

If published content references media, expose only an approved public media representation. Do not
serialize bucket names, private object keys, credentials, or internal storage URLs merely for Astro
convenience.

If no suitable media contract exists, report the gap instead of inventing a controller-local format.

## OpenAPI

Update the existing **v0** OpenAPI 3.0.4 descriptions to match any approved contract changes.

Do not add v1 paths.

Preserve the existing requirements:

- actual routes/hosts only;
- RFC 9457 errors by reference;
- no internal hosts;
- Committee request/response validation;
- generated bundle drift checks;
- bidirectional route/OpenAPI coverage.

Because v0 is intentionally mutable, an approved coordinated change may update the existing v0
schema directly.

## Tests

Use Minitest and the repository's established contract layers.

### Resolver/query tests

Cover at minimum:

- canonical published -> current;
- redirect slug -> moved + canonical target;
- explicitly withdrawn -> gone if domain semantics support it;
- draft/reserved/unpublished -> not found;
- unknown -> not found;
- audience isolation;
- content-surface isolation;
- locale isolation.

### Serializer/value tests

After API shape approval, cover:

- exact required keys/types where repository convention requires exactness;
- public identifiers only;
- immutable published version marker;
- deterministic public updated_at semantic;
- structured body remains structured JSON;
- taxonomy comes from the published-version snapshots.

### Controller/integration tests

Cover:

- 200 current document;
- approved moved-document contract;
- 404 unknown/hidden;
- 410 where domain semantics justify it;
- RFC 9457 shape/media type;
- ETag;
- Last-Modified;
- 304;
- bounded index pagination;
- invalid limit/cursor behavior;
- lightweight sitemap feed if approved;
- all 12 host-constrained combinations.

### OpenAPI tests

Cover the modified v0 operations and ensure route/description accuracy remains bidirectional.

## Implementation order

1. Read AGENTS, applicable rules, ADRs, and current code.
2. Report conflicts between this plan and current repository facts.
3. Keep the work on `/api/v0`; do not design v1.
4. Present the required Before/After API-shape and lifecycle/status proposal.
5. Wait for explicit user approval of the machine-readable shape.
6. Implement the lifecycle resolver/query using the current publishing domain.
7. Adapt the existing v0 serializer/read contract for Astro as approved.
8. Prove one representative surface/audience vertically.
9. Update OpenAPI v0 and focused tests for that slice.
10. Apply the proven wiring across all 12 surface/audience combinations.
11. Add a lightweight sitemap metadata endpoint only if investigation shows it is needed and its
    shape is separately approved.
12. Leave browser-direct search as a future v0 task.
13. Run focused verification, then the broader risk-appropriate suite.

Do not deploy, perform destructive publishing migrations, alter Cloudflare resources, or add v1 as
part of this task.

## Acceptance criteria

This Rails slice is complete when:

- central `publishing` DB remains the sole content authority;
- Astro-facing content remains under `/api/v0`;
- no `/api/v1` content/search API is introduced;
- any v0 shape change passed the repository's explicit Before/After approval gate;
- Astro can fetch a full published document server-side;
- current, moved, hidden/not-found, and legitimately gone states are represented correctly;
- hidden editorial state is not disclosed;
- a stable immutable published-version marker is available if approved;
- a documented public updated_at semantic is available if approved;
- ETag / Last-Modified / 304 remain correct and tested;
- index pagination remains bounded/cursor-based;
- Astro can obtain sitemap metadata without Rails generating sitemap XML;
- Rails does not own canonical/hreflang presentation URLs;
- OpenAPI 3.0.4 v0 descriptions remain accurate;
- search remains a future browser->Rails `/api/v0/...` design with no placeholder implementation;
- focused and required broader tests are green.
