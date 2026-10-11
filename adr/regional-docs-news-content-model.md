# ADR: Regional Docs and News Content Model

## Status

Superseded by `adr/publishing-db-content-authority.md` (2026-07-16)

Accepted (2026-04-16)

> **Superseded:** Regional placement for docs/news and the `Document`/`Timeline` model family are
> retired. Content authority is centralized in the `publishing` database through
> Entry/Revision/Version/Publication. The separation of Revision as edit history and Version as a
> published snapshot carries into the new design. Taxonomy (one category and many tags) will not be
> copied directly into the new database and requires a separate ADR.

## Context

The `Regional` engine owns the `docs`, `help`, and `news` application surfaces.

For the current implementation track, only `docs` and `news` need a content model decision.

Repository inspection showed:

- `docs` already aligns with the `Document` model family on `PublicationRecord`
- `news` already aligns with the `Timeline` model family on `PublicationRecord`
- `avatar.posts` and `post_versions` exist but are not the intended storage for `docs/news`
- taxonomy masters use self-referential `parent_id` trees
- category assignment tables are single-valued per entry
- tag assignment tables are multi-valued per entry
- both `revision` and `version` exist for `Document` and `Timeline`

Without an explicit decision, implementers would need to guess:

- which model family is canonical for each surface
- whether `revision` and `version` are redundant
- whether category and tag assignment are meant to be symmetric
- whether editing should happen outside the staff CMS surface

## Decision

We accept the following model for `Regional` content.

### 1. Surface-to-model mapping

- `docs` uses the `Document` model family
- `news` uses the `Timeline` model family
- `help` is not included in this decision
- `avatar.posts` is out of scope for `docs/news`

### 2. Editing and delivery boundaries

- editing is performed only from the `org` staff CMS surface
- public read delivery exists for `app`, `com`, and `org`

### 3. Revision and version roles

Keep both `revision` and `version` and split their responsibilities:

- `revision` is the draft and working-history record
- `version` is the public release snapshot

Draft save behavior:

- each draft save creates a new `revision`

Publish behavior:

- publish creates or promotes a `version` from a selected `revision`
- public read resolves from `latest_version_id`
- `latest_revision_id` remains the working/history pointer

### 4. Taxonomy rules

Keep recursive taxonomy trees.

- taxonomy masters remain tree-structured through `parent_id`
- recursive traversal is the accepted read model

Assignment rules:

- category is one-per-entry
- tag is many-per-entry

This means category and tag are intentionally not symmetric.

### 5. Publication rules

Public readability depends on both:

- published status
- publish window defined by `publish_at` and `expires_at`

## Consequences

- `docs` controller and service work must target `*Document*` models only
- `news` controller and service work must target `*Timeline*` models only
- public read endpoints must not resolve from draft `revision` records
- staff CMS can support draft history and public release snapshots without inventing a third model
- taxonomy editing can be postponed while taxonomy assignment still works
- `help` can be designed later without coupling it to `docs/news`

## Related

- `adr/news-is-timeline.md`
- `docs/architecture/regional-content.md`
