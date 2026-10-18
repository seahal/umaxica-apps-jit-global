# Docs, Help, And News Phase 1 Audit

## Context

The current direction keeps `docs`, `help`, and `news` as host-constrained Rails content authority
surfaces, while Next.js owns the public frontend. This memo records current repository gaps that a
later implementation should address. It is not source of truth; promote stable decisions to ADRs or
docs.

## Observed

- `config/routes/docs.rb`, `config/routes/help.rb`, and `config/routes/news.rb` already use
  host-constrained routing for `app`, `com`, and `org`.
- Current Rails routes still expose `/entries` and `/entries/:slug` for `docs`, `help`, and `news`.
  These are HTML article routes and conflict with the Next.js frontend ownership direction.
- Current Rails routes still expose `/robots.txt` for `docs`, `help`, and `news`. The new direction
  assigns `robots.txt` to Next.js unless deployment or ingress constraints prove Rails must keep it.
- Current Rails root controllers call `render_content_index`, which reads content entries and
  renders an article index. The target root is a thin `200 OK` endpoint.
- `app/controllers/concerns/read_only_content_rendering.rb` currently has both HTML and JSON paths.
  The JSON read-contract path remains useful; the HTML path is not target behavior.
- `app/views/shared/content_entries/index.html.erb` and
  `app/views/shared/content_entries/show.html.erb` are Rails article-rendering views for this
  feature area. They should become unused after HTML routes and root index rendering are removed.
- `app/services/oidc_client_registry.rb` still contains `docs_*`, `help_*`, and `news_*` client
  entries. OIDC cleanup is out of scope for the Phase 1 shrink, but these entries are not
  authoritative for the new content boundary.
- Current docs/help/news Rails controllers use surface-local `BareController` classes that inherit
  directly from `ActionController::Base` and declare `AUTHENTICATION_MODE = :bare`.

## Why It Matters

- Leaving Rails article routes active makes Rails a competing public HTML owner.
- Leaving Rails `robots.txt` active can split SEO ownership between Rails and Next.js.
- Leaving root as a content index violates the thin-root boundary even if article routes are later
  removed.
- OIDC registry entries may confuse future work into treating docs/help/news as RPs.

## Open Questions

- Does production ingress require Rails to answer `robots.txt` on docs/help/news hosts?
- What exact API path naming should replace or bless the current read contract? This was explicitly
  left out of the Phase 1 decision.
- Should `org` docs/help/news reads remain public permanently, or become authenticated/org-scoped in
  a later phase?

## Promotion Candidate

- If Phase 1 is implemented, update `docs/architecture/docs-help-news-content-boundary.md` with the
  exact Rails routes that remain.
- If OIDC client entries are removed later, update the relevant identity/registry documentation and
  tests together.
