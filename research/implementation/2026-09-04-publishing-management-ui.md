# Publishing Management UI Implementation Notes

## Context

- Original plan/spec: conversation request for Base.Org Publishing CMS index/show/edit/update
- Related decisions/docs/plans: `docs/architecture/publishing-persistence.md`,
  `adr/org-cloudflare-access-authentication-layer.md`
- Implementation date: 2026-09-04

## Decisions Made During Implementation

- Decision: management cell is audience+surface across locales, not one Edition
  - Why: Editions are unique on audience+surface+locale
  - Alternatives considered: locale in the path
  - Follow-up needed: none for this slice

- Decision: `PublishingRevisionContentDigest` is the production digest for new CMS revisions
  - Why: no existing production digest implementation
  - Alternatives considered: copy test-fixture `Digest::SHA256.hexdigest("#{title}-#{sequence}")`
  - Follow-up needed: none; recorded in `docs/architecture/publishing-persistence.md`

- Decision: Rails authentication is absent; controllers inherit `BareController`
  - Why: requested alpha posture (Cloudflare Access in front, later)
  - Alternatives considered: Operator session
  - Follow-up needed: Access coverage for `base.org` or `/publishing/*` before external exposure

## Deviations From Plan

- Change: 422 re-renders the edit Inertia component by `controller_path/edit` rather than
  `render inertia: true`
  - Why: `render inertia: true` on update names the `update` component, which does not exist
  - Risk: low
  - Follow-up: none

## Review Notes

- Tests run: route contract, operation, CMS controller/integration, digest, matrix, Vitest, RuboCop,
  org dashboard, `ri` contract, public entrypoint inventory, full `bin/rails test`
- Full suite remaining failures: health helper/url 404s, host authorization `jp.umaxica.dev`; not
  CMS-specific after inventory/`ri` allowlist updates
- Documentation promotion needed: management hierarchy recorded in
  `docs/architecture/publishing-persistence.md`
