# Publishing Persistence And Controller Design

Current architecture after the twelve-family encrypted persistence rewrite. See
`adr/publishing-twelve-family-encrypted-persistence.md`.

## Persistence is global

The 3 × 4 content matrix shares one `publishing` database. There are not twelve CMS databases. Each
cell is a physical table family:

`Publishing::Docs::App::Entry` → `publishing_docs_app_entries`

Family identity is the table/class. Do not persist `audience` or `surface` on content rows. Locale
is a column inside the family. Region is `Entry::REGION_CODE`.

## Persistence polymorphism is prohibited

No polymorphic associations, STI, exclusive-arc owners, discriminator ownership, or `constantize`
for family selection. Ruby modules/Concerns share behavior.

## Encryption

Revision and version `title`, `summary`, and `body` use non-deterministic Active Record Encryption
(existing key provider). PostgreSQL stores ciphertext `text`. Ruby sees String title/summary and a
Hash body. `content_digest` is SHA-256 of canonical plaintext and is not a confidentiality control.

## Media

`publishing_media_files` is global. Revision/version media usages are family-owned with a single
explicit owner FK.

## Rails controllers

Each public and management controller declares `PUBLISHING_AUDIENCE`, `PUBLISHING_SURFACE`, and
`ENTRY_CLASS` explicitly.

Public URLs: `GET /api/v0/entries`, `GET /api/v0/entries/:public_id`. Management URLs:
`/publishing/{info,docs,news,help}/{app,com,org}/entries` on `edit.umaxica.org`.

Public read controllers inherit the cache default from their surface-local `BareController` and opt
in to public caching in `PublishingContentRendering`. Management controllers inherit `no-store` from
`Edit::Org::ApplicationController` and never opt in. See `docs/reference/http-cache-policy.md`.

The edit host is the staff Publishing management boundary. The Publishing database remains in this
Rails application while the identity/operator contract is stabilized; this host move deliberately
does not extract Publishing persistence or introduce cross-database associations.

## Edit landing navigation

Anonymous Publishing management requests start Edit's OIDC flow. On a host that is not same-site
with the Base authority (for example `edit.org.localhost`), the authorize redirect goes through the
Jump gateway with an `EDIT_ORG` rt whose keys Edit publishes at `/.well-known/jwks.json`; see
`docs/operations/jump-rt-key-rotation.md`.

Edit's root uses its surface layout with the same typography, column width, and action styling as
the Base landing. Anonymous visitors enter the existing authenticated Publishing dashboard through
Sign in; its authentication boundary initiates Edit's OIDC flow. Sign up opens the Base org root,
where the existing CSRF-protected registration admission form owns account creation. Signed-in
operators see a Publishing dashboard link. The footer links to Base org preferences with an
absolute URL, preserving regional context. Edit does not duplicate Base's identity or preference
controllers. The root response uses `private, no-store` because its navigation depends on login
state.
