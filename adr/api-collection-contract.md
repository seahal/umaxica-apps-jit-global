# API Collection Contract: Envelope and Cursor Pagination

**Status:** Accepted (2026-08-16); implemented (2026-08-22); pagination mechanism superseded
(2026-09-10) by `adr/api-collection-offset-pagination.md`. The `{ data, page }` envelope and
unwrapped single-resource object remain in force.

> This ADR recorded a target contract and deferred it as externally breaking. The migration
> constraint rested on a premise that a later audit disproved, and the contract was implemented on
> 2026-08-22 — see [Migration constraint](#migration-constraint) and
> [Implementation 2026-08-22](#implementation-2026-08-22).

## Status

Accepted (2026-08-16) for the success envelope. **Pagination mechanism superseded** on 2026-09-10
by `adr/api-collection-offset-pagination.md` (Pagy offset pages). Do not implement the signed
cursor described below.

**No standard governs this area.** HTTP defines no pagination mechanism and no response-envelope
convention. This record therefore states a repository decision and names the de facto practice it
follows, rather than citing a specification. It is kept out of
`docs/reference/api-design-standards.md` for exactly that reason.

## Context

Collection endpoints today return every matching row with no bound.
`render_publishing_entries_index` (`app/controllers/concerns/publishing_content_rendering.rb:13-14`)
renders `{"entries": [...]}` from `publishing_entries_query.call.filter_map { … }` — the complete
set of published entries for the edition, with no limit, no cursor, and no `Link` header. The
response grows without bound as content is published.

Envelope keys are chosen per endpoint with no shared convention. Observed: `{"entries": [...]}` and
`{"entry": {...}}` (`publishing_content_rendering.rb:14,21`), `{"refreshed": true}`
(`app/controllers/concerns/core_browser_api_boundary.rb:135`),
`{"authenticated", "csrf_token", "actor"}`
(`app/controllers/core/app/api/v0/sessions_controller.rb:15-21`).

Two options were considered:

- **Offset pagination** (`?page=&per_page=`). Simple and familiar, but it skips and duplicates rows
  when the underlying set changes between requests, and its cost grows with depth because the
  database must still traverse the skipped rows. Rejected.
- **Cursor pagination**, as implemented by GitHub and Stripe. Stable under concurrent writes and
  constant-cost at any depth, at the price of losing random access to an arbitrary page. Accepted;
  the content endpoints here are read-forward feeds, not random-access tables.

## Decision

**Every collection endpoint is paginated. An unbounded collection response is a defect.** The page
size is a server-side guarantee, not a client courtesy — a client that omits `limit` must still
receive a bounded response.

Request parameters: `?limit=<1..100>&cursor=<opaque>`. `limit` defaults to 20. A `limit` above the
maximum is clamped, not rejected, so a client cannot turn a tuning mistake into an error.

Response envelope:

```json
{
  "data": [ … ],
  "page": { "next_cursor": "…", "has_more": true }
}
```

- `has_more` is authoritative. `next_cursor` is `null` when `has_more` is `false`.
- **The cursor is opaque.** It is never a raw offset, a primary key, or any value a client can
  construct or interpret. Because it is opaque, its encoding may change without a version bump; that
  is the point of making it opaque.
- Single-resource responses return the resource object at the top level, with no wrapper key.

Offset pagination must not be added to any public collection.

## Migration constraint

> **Superseded 2026-08-22.** The premise below — that edge applications consume the entries API —
> was disproved by the audit in `plans/rails-nextjs-openapi-contract-audit.md`. Retained as the
> reasoning at the time. See [Implementation 2026-08-22](#implementation-2026-08-22).

This contract cannot be applied to the existing entries API without an externally coordinated
breaking change.

- `test/contracts/publishing_entry_api_contract_test.rb:29` asserts
  `assert_equal ENTRY_KEYS, entry.keys` — an exact key-set match. The file's opening comment states
  it "Pins the public read contract consumed by the edge applications", and that adding, removing,
  or retyping a field there is a deliberate API change.
- Those edge applications live outside this repository
  (`docs/operations/core-nextjs-zero-cookie-edge-contract.md`). No code under `src/` consumes the
  entries API.

Consequently:

1. Changing `{"entries": [...]}` to `{"data": [...], "page": {...}}` requires `Deprecation` and
   `Sunset` headers and an announced window, per `docs/reference/api-design-standards.md`. Neither
   header is implemented anywhere in the repository today.
2. Introducing a default `limit` is itself breaking for any consumer that currently relies on
   receiving the complete set in one response. It cannot be shipped as a silent change.
3. The contract test is the coordination point: it must be updated in the same change that ships the
   new shape, never loosened in advance to make room for it.

Conditional-request support (`ETag` / `Last-Modified` / `304`) for these endpoints is separate from
pagination and is not blocked by it; it is governed by `docs/reference/api-design-standards.md` and
adds no breaking change.

## Implementation 2026-08-22

The migration constraint above assumed a consuming client. There is none.

- `seahal/umaxica-apps-edge` forwards `/api/v0/*` to Rails byte for byte over a Cloudflare VPC
  binding and never parses the JSON (`app/core/src/lib/core-dispatch.ts:43`, `:115-133`). It has no
  named call site for any entries path, no TypeScript type for a Rails response, and no occurrence
  of the string `openapi` anywhere in the repository.
- No code under `src/` consumes it either, as this ADR already recorded above.
- `adr/api-versioning-and-client-conventions.md` states that `v0` means the contract is not frozen,
  and the `Sunset` requirement in `docs/reference/api-design-standards.md:228-243` is scoped to
  endpoint removal, not to a response-shape change.

With no consumer to coordinate with and no frozen contract to break, points 1 and 2 of the migration
constraint no longer apply. Point 3 was honoured: the contract test was updated in the same change
that shipped the shape, never loosened in advance.

What shipped:

- `{"entries": [...]}` became `{"data": [...], "page": {"next_cursor": …, "has_more": …}}`, and the
  single-resource response lost its `{"entry": …}` wrapper.
- `?limit=<1..100>&cursor=<opaque>`, `limit` defaulting to 20 and clamped rather than refused. A
  `limit` that is not a whole number, and a cursor that does not verify, are refused with `400`
  rather than silently treated as the default — answering with page one would return the wrong rows
  while looking successful.
- `PublishingEntriesCursor` signs the cursor with `Rails.application.message_verifier`, following
  `SessionLimitResolutionTokenRef`. The payload carries the publication instant and the entry's
  `public_id`, never a primary key, and the signature is what makes it unconstructible by a client.
- `PublishingPublishedEntriesQuery#page` reads one row past the page to decide `has_more` rather
  than issuing a second COUNT. Its ORDER BY tiebreaker moved from the primary key to `public_id` so
  that the keyset predicate and the cursor can share a sort key that carries no internal identifier.
- The ETag now covers the whole envelope, so it is page-specific.

Not done, and deliberately: no index was added for `(effective_from, public_id)`. The previous
unbounded query already sorted on `effective_from` without one, and bounding the result set reduces
the work rather than increasing it. An index is a separate decision under
`.agents/harnesses/rules/generic/migrations.mdc`.

## Scope

- The success-response envelope for collections and single resources.
- The pagination mechanism, its parameters, defaults, and bounds.
- The requirement that the cursor be opaque.

## Non-scope

- Error responses — `adr/api-error-format-problem-details.md`.
- Caching and conditional requests — governed by RFC 9110 and recorded in
  `docs/reference/api-design-standards.md`.
- Any implementation in this change. No controller, serializer, query, or test is modified by
  recording this decision.
- Sorting and filtering parameters, which are not decided here.

## Consequences

- Collection responses gain a bound, removing an unbounded-growth path in both response size and
  database work.
- One envelope convention replaces per-endpoint key invention, so a client can process any
  collection without per-endpoint code.
- The entries API migration is externally breaking and cannot proceed until the edge applications
  are coordinated and a sunset window has elapsed. Recording this decision does not authorize that
  change.
- Losing random access to page N is accepted. If a future endpoint genuinely needs it, that endpoint
  requires its own decision rather than a quiet exception here.
