# API Collection Pagination: Pagy Offset Pages

**Status:** Accepted (2026-09-10)

**Supersedes:** the pagination mechanism in `adr/api-collection-contract.md` (signed cursor,
`next_cursor` / `has_more`, caller `limit`). That ADR remains the historical record for the
`{ data, page }` success envelope and the single-resource unwrapped object.

> **No standard governs this area.** HTTP defines no pagination mechanism. This record states a
> repository decision.

## Context

Public publishing collection endpoints (`GET /api/v0/entries` on all twelve surface × audience
cells) used a custom keyset cursor signed with `Rails.application.message_verifier`. That design
matched an earlier decision that offset pagination was unacceptable.

The application has not frozen `v0` and has no in-repo consumer of the cursor contract. The signed
cursor, `limit`, `next_cursor`, and `has_more` therefore imposed a private pagination library on
every caller, including a future Astro consumer that needs random access to page N.

Pagy 43.6.2 is already a locked dependency and was unused in `app/`. Its offset paginator is the
ordinary, documented API (`pagy(:offset, collection, **options)` after `include Pagy::Method`).
Source: https://ddnexus.github.io/pagy/toolbox/paginators/offset/

## Decision

Collection pagination for the public publishing entries API is **Pagy offset pagination**.

- Request: `GET /api/v0/entries?locale=ja&page=2` (plus existing `category` / `tag` filters).
- Callers send a 1-based logical page number. They do not send a SQL `OFFSET` or a page size.
- Page size is server-controlled and is currently 20 (`PublishingPublishedEntriesQuery::PAGE_SIZE`).
- Response envelope:

```json
{
  "data": [ { } ],
  "page": { "current": 2, "previous": 1, "next": 3, "last": 10 }
}
```

`previous` and `next` are `null` when there is no adjacent page. The envelope is application-owned;
Pagy internals are not serialized.

- Invalid `page` (not a whole number ≥ 1) is refused with `400` application/problem+json. Pagy 43's
  request parser would otherwise coerce non-numeric values to page 1.
- Out-of-range `page` uses Pagy's `raise_range_error: true` and is refused with `400` rather than
  returning an empty page or remapping to page 1.
- Shared implementation lives in `PublishingContentRendering`. The twelve cell controllers keep
  explicit `PUBLISHING_AUDIENCE`, `PUBLISHING_SURFACE`, and `ENTRY_CLASS`.
- `PublishingPublishedEntriesQuery` returns a filtered, deterministically ordered relation
  (`effective_from DESC`, `public_id DESC`). Pagy applies `LIMIT`/`OFFSET`.
- `PublishingEntriesCursor` is removed.

Offset pagination remains replaceable later with Pagy `:keyset` / `:keynav` if measurements justify
it. That change would be a new ADR.

## Alternatives considered

- Keep the signed cursor. Rejected: no frozen consumer, and page-number access is the intended
  contract for the Astro reader.
- Pagy keyset now. Rejected: first implementation prefers the ordinary offset paginator; keyset
  remains available on the same gem.
- Caller-controlled `limit`. Rejected: the previous `limit` existed only for the cursor design.

## Consequences

- Random access to page N is available; concurrent writes can skip or duplicate rows across pages.
- Deep pages pay `OFFSET` scan cost. That is accepted until measured.
- Management HTML listing (`PublishingManagementEntriesQuery`) is unchanged.
