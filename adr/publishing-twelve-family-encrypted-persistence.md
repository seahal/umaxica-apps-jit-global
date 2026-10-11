# ADR: Twelve Physical Publishing Families And Encrypted Content

## Status

Accepted (2026-09-04)

## Date

2026-09-04

## Context

The publishing database stored all twelve audience × surface cells in one table family keyed by
`Publishing::Edition` (`audience`, `surface`, `locale`). Human authored revision and version content
(`title`, `summary`, `body`) was plaintext.

That design used discriminator columns to emulate twelve CMS cells. Persistence polymorphism remains
forbidden. Publishing is not deployed with production content, so a destructive pre-deployment
rewrite is authorized.

This ADR supersedes `adr/publishing-db-content-authority.md` §3 (Edition multiplex) and §9 (forbid
surface-specific models; audience-first naming). It amends `adr/publishing-taxonomy-architecture.md`
vocabulary scope and `adr/publishing-persistence-polymorphism-prohibition.md` to cover family
ownership, not only media exclusive-arc tables.

## Decision

1. One `publishing` database via `PublishingRecord`. Not twelve databases.
2. Twelve physical table/model families named surface-first: `Publishing::Docs::App::Entry` →
   `publishing_docs_app_entries`.
3. No `audience`/`surface` ownership columns on content rows. Locale remains data inside each
   family. Region is a family constant (`REGION_CODE`), not a column. `Publishing::Edition` is
   removed.
4. Vocabularies, terms, assignments, and media usages are family-owned. `Publishing::MediaFile`
   stays global.
5. Runtime classes are explicit files. Migration helpers may iterate the 3×4 matrix. No
   `constantize` for family selection.
6. Revision and version `title`, `summary`, and `body` use non-deterministic Active Record
   Encryption. Columns are `text`. Body remains a Hash in Ruby. `content_digest` stays SHA-256 of
   canonical plaintext (non-secret integrity identifier; identical content yields identical
   digests).

## Consequences

- Public `GET /api/v0/entries` and management `/publishing/{surface}/{audience}/entries` stay.
- PostgreSQL cannot validate encrypted body JSON; Ruby validations replace `jsonb_typeof(body)`.
- Integrity triggers are wired per family using shared parameterized functions.
