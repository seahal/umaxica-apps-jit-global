# ADR: Content-Attached Discussion, Moderation, And Notification For Docs, Help, And News

## Status

Proposed (2026-06-16)

Constraint added 2026-10-05:
`adr/oidc-oauth-participation-allowlist-and-non-participant-surfaces.md` keeps Docs, Help, and News
outside the OAuth/OIDC RP system. Per-user state in this proposal, such
as `watch_state`, `tracking_state`, and `muted_state`, must be served through an authenticated
RP-owned boundary rather than by making a content surface an RP.

## Context

Umaxica has three information surfaces — `docs`, `help`, and `news`. Today they are read-only
content authority surfaces in this Rails repository, with the public frontend owned by Next.js. The
current boundary is recorded in `adr/read-only-content-surfaces-in-rails.md`,
`adr/news-is-timeline.md`, and `docs/architecture/docs-help-news-content-boundary.md`.

We want these surfaces to stop being purely one-way content delivery and to support discussion
attached to each entry, plus the moderation and notification primitives that make attached
discussion safe to operate. This ADR records the design direction and the responsibility boundary
for that capability. It does not authorize implementation; no model, migration, route, controller,
view, or Next.js change is made by this record.

We take selected operational and information-flow ideas from two prior-art systems, without aiming
for compatibility with either:

- From Discourse: discussion attached to content, trust level, moderation, flagging, and
  notification granularity such as reply / mention / watching / tracking / muted.
- From Forem / DEV.to: tag-driven discovery, separation of public profile from real identity, and
  feed / activity / graph design as future reference only.

We explicitly do not bring a Forem clone, a full SNS, or a follow graph into the initial Docs / Help
/ News discussion scope.

A factual constraint must be recorded so this ADR is not read against the current code:

- The current v1 content tables (`docs_content_entries`, `news_content_entries`,
  `help_content_entries` in the surface zenith databases) store only `slug`, `locale`, `title`,
  `summary`, `body`, `status`, and `published_at`. They have no tag columns.
- `adr/read-only-content-surfaces-in-rails.md` explicitly abandoned taxonomy for v1: "Tags,
  categories, taxonomy builders, and taxonomy master model families are not part of the current
  routing or persistence boundary."
- `adr/news-is-timeline.md` references a historical `Timeline` family with tags, but no `*_tags`
  tables and no `Timeline`/tag models exist in the current schema.

So "Docs / Help / News tags already exist" is a design assumption for the discussion model to
reference, not a statement about current schema. Where this ADR refers to existing tags, it means
"reuse whatever entry/tag mechanism is in place at implementation time and do not make a new tag
model the goal of this work." If no tag mechanism exists when discussion is implemented, that gap is
resolved against `adr/read-only-content-surfaces-in-rails.md`, not by this ADR.

## Decision

1. Each `docs`, `help`, and `news` entry can have discussion attached to it after the fact.
   Discussion is an opt-in, additive capability on top of the existing read-only content entry; it
   does not change the entry as the authoritative content record.
2. Docs / Help / News tags are treated as belonging to the existing entry model. Adding a new tag
   model is not a goal of this work. Discussion references whatever tag/entry mechanism exists at
   implementation time (see the Context constraint above).
3. Discussion, Notification, Permission, and Moderation are designed to reference the existing tag,
   entry, and surface context so that they can be evaluated and displayed per surface and per entry.
4. Rails does not implement UI for this capability.
5. Article / card / list UI, filter UX, layout, and interaction are the responsibility of the
   Next.js frontend.
6. Rails responsibility is limited to: API contract, authorization policy, event emission,
   notification state, moderation state, and the read model exposed to the frontend.
7. Acme remains the authority for real identity, authentication, and authorization.
8. Public profile is not mixed with Acme identity. The display-facing profile is a Core / Community
   public-surface concern, not an Acme identity projection.
9. Full SNS, social graph, follow graph, and activity graph are not mixed into the initial Docs /
   Help / News discussion scope. They are deferred to a larger future design spanning Core / Base /
   Palm.
10. We do not target Discourse or Forem compatibility. We borrow only their operational and
    information-flow design.

### Rails API contract direction

The read model / API fields below are recorded as candidate fields for what Rails may return to
Next.js. This is contract intent, not a confirmed implementation or schema. Field names, presence,
and shape are decided when the read model is implemented.

- `title`
- `slug`
- `summary` / `excerpt`
- `tags`
- `published_at`
- `updated_at`
- `discussion_ref`
- `discussion_count`
- `watch_state`
- `tracking_state`
- `muted_state`
- `author_profile_ref`
- `visibility`
- `moderation_state`
- `policy_context`

Constraints on the contract direction:

- The read API resource noun stays `entries` (per `adr/read-only-content-surfaces-in-rails.md`); a
  discussion read model is an addition to that contract, not a `posts` resource.
- `author_profile_ref` and any profile field reference a public profile, never Acme identity,
  credentials, email, phone, passkey, TOTP, secrets, or OAuth subject.
- `policy_context` and `moderation_state` are server-authoritative; the frontend renders them but
  does not decide them.

## Consequences

Benefits:

- Docs / Help / News can carry discussion attached to each entry.
- The connection between content and discussion becomes explicit.
- Notification, moderation, and trust become reusable foundations that can span surfaces.
- The Rails / Next.js responsibility split is preserved.
- Acme identity and public profile stay separated.

Tradeoffs:

- The Rails API contract grows.
- Notification, moderation, and policy design is required earlier than a pure content-delivery model
  would need.
- Attaching discussion to an entry requires event and read-model design.
- Because UI is owned by Next.js, the feature is not visible as a finished product from Rails alone.

Rejected / Deferred:

- Building article / card / list UI in Rails. (Rejected — owned by Next.js.)
- Implementing UX in Rails. (Rejected — owned by Next.js.)
- Adding a new tag model to Docs / Help / News as the goal of this work. (Deferred — resolved
  against `adr/read-only-content-surfaces-in-rails.md` if a tag mechanism is needed.)
- A Forem clone. (Rejected.)
- A Discourse clone. (Rejected.)
- Including a full SNS in this scope. (Deferred to a Core / Base / Palm design.)
- Including a follow graph / social graph in this scope. (Deferred.)
- Treating Acme identity and public profile as the same thing. (Rejected.)

## Related

- `adr/read-only-content-surfaces-in-rails.md` — current read-only content boundary; taxonomy
  abandoned for v1.
- `adr/news-is-timeline.md` — historical timeline/tag context for news.
- `adr/identity-authority-boundary.md`, `adr/acme-sign-core-base-port-boundary.md` — Acme as
  identity authority.
- `docs/architecture/docs-help-news-content-boundary.md` — current Rails / Next.js responsibility
  split.
- `memos/2026-06-16-claude-content-discussion-profile-feed-boundary.md` — implementation-leaning
  scope notes and future checkpoints for this ADR.
