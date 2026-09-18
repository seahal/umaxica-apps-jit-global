# ADR: Regional Help Surface Direction

## Status

Superseded by `adr/publishing-db-content-authority.md` (2026-07-16)

Accepted (2026-04-16)

> **Superseded:** Help no longer belongs to the Regional content database group. Like
> info/docs/news, it is a global content surface owned by the central `publishing` database. The new
> design preserves the decisions that help is not the inquiry/contact implementation surface and
> that its data is document-like: an entry, edit history, and published snapshots.

## Context

The `Regional` engine owns `docs`, `help`, and `news` as application surfaces.

During the current planning track, `help` was re-evaluated because inquiry/contact work moved to the
`base` surface.

Repository inspection and planning discussion established the following:

- `help` should not be grouped into the same active implementation track as `docs/news`
- inquiry/contact is planned under `base`
- `help` still needs to remain as a named `Regional` surface
- no immediate homepage or content implementation is required
- future `help` content is expected to be FAQ-like or support-content-like
- future `help` editing should follow the same `org` staff CMS editing boundary used by `docs/news`
- `help` should continue using the `Regional` content database group selected for these surfaces

Without an explicit decision, later implementation work would need to guess:

- whether `help` is still an inquiry surface
- whether `help` should be coupled to `docs`
- whether `help` requires its own database family immediately
- whether a homepage must exist before the content model is designed

## Decision

We accept the following direction for `help`.

### 1. Product role

- `help` is separate from `docs` and `news`
- `help` is not the inquiry/contact implementation surface
- inquiry/contact belongs to `base`

### 2. Current implementation state

- `help` remains a reserved `Regional` surface
- `help` does not require a v1 homepage
- `help` does not require a v1 content model implementation yet

### 3. Future implementation direction

- future `help` editing belongs only to the `org` staff CMS surface
- future `help` content should be document-like in structure
- document-like means entry + draft/history + public snapshot
- `help` should remain extensible in the same general way as `docs/news`

### 4. Storage boundary

- `help` remains within the same `Regional` content database group selected for `docs/news`
- this decision does not require a dedicated `Help*` model family yet

## Consequences

- current `docs/news` implementation can proceed without blocking on `help`
- `help` can be implemented later without reopening the inquiry/contact decision
- later `help` work should not assume timeline-like content
- later `help` work should not assume a separate non-staff editing surface
- routes and naming for `help` can remain in place even while the surface is inactive

## Related

- `adr/regional-docs-news-content-model.md`
