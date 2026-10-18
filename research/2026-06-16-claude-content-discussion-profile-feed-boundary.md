# Content-Attached Discussion, Profile, And Feed Boundary For Docs/Help/News

## Context

This memo is the implementation-leaning companion to
`adr/docs-help-news-discussion-moderation-notification.md`. The ADR records the decision and
boundary; this memo records scope, future checkpoints, and boundary notes to help a later
implementer avoid rediscovery. It is not source of truth; promote stable content to the ADR or
`docs/`.

The design borrows operational and information-flow ideas from Discourse (content-attached
discussion, trust level, moderation, flagging, notification granularity) and Forem / DEV.to
(tag-driven discovery, profile vs identity separation, feed/graph as future reference), without
targeting compatibility with either.

## Observed

- Current v1 content tables (`docs_content_entries`, `news_content_entries`, `help_content_entries`
  in the surface zenith databases) store only `slug`, `locale`, `title`, `summary`, `body`,
  `status`, `published_at`. No tag columns exist.
- `adr/read-only-content-surfaces-in-rails.md` abandoned taxonomy for v1; no `*_tags` tables and no
  `Timeline`/tag models exist in the current schema, despite `adr/news-is-timeline.md` referencing a
  historical tagged `Timeline` family.
- Consequence: the ADR's "tags already exist" premise is a design assumption for the discussion
  model to reference, not current schema. A real tag mechanism may still need to be defined, and
  that gap is resolved against `adr/read-only-content-surfaces-in-rails.md`, not by the discussion
  ADR.
- Docs/help/news Rails controllers currently use surface-local `BareController`
  (`AUTHENTICATION_MODE = :bare`); discussion/moderation/notification will need an authenticated
  authority path that does not turn these content surfaces into identity/session/authorization
  authorities.

## In Scope (this design)

- Discussion attached to a Docs / Help / News entry.
- Trust level.
- Moderation.
- Flagging.
- Notification.
- Public profile reference.
- Reuse of existing tags.
- Read model / API for Next.js.

## Out Of Scope (this design)

- Rails UI.
- Article / card / list UI.
- Next.js implementation.
- Full SNS.
- Follow graph / social graph.
- Forem clone.
- Discourse clone.
- Changes to the Acme identity model.
- Model / migration / route implementation changes.

## Suggested Future Implementation Checkpoints

- Can a Docs / Help / News entry reference a discussion topic?
- Can a discussion topic identify its source surface?
- Can a discussion topic identify its source entry?
- Can a discussion topic reference existing tags?
- Can a notification event represent reply / mention / watch / tracking / muted?
- Can moderation state represent visible / hidden / flagged / under_review / rejected and similar?
- Can trust-level policy be evaluated per actor, per surface, and per action?
- Is the public profile reference separated from Acme identity?
- Can Next.js obtain the read model it needs from the Rails API?
- Can the design extend to security notification and workflow notification later?

## Boundary Notes

- Acme is the real identity authority; it is not the public profile.
- Public profile is a display-facing persona; it must not expose credential, email, phone, passkey,
  TOTP, secret, or OAuth subject data.
- UI/UX is implemented on the Next.js / Core side.
- Rails owns authoritative data, policy, event, state, and API contract.
- Full SNS / graph is not mixed into Docs / Help / News discussion; it is deferred to a future Core
  / Base / Palm design.

## Open Questions

- What is the storage authority for discussion topics, notification state, and moderation state, and
  which database/surface owns it?
- Does discussion live per surface (app/com/org host variants) the same way content entries do, or
  is it cross-surface?
- Where does the public profile model live (Core / Community), and what is the reference shape Rails
  exposes as `author_profile_ref` without leaking Acme identity?
- Does a tag mechanism need to be introduced first (resolved against
  `adr/read-only-content-surfaces-in-rails.md`) before tag-referencing discussion is meaningful?

## Promotion Candidate

- When discussion/moderation/notification is scheduled for implementation, promote the storage
  authority and surface-scoping decisions into the ADR and into
  `docs/architecture/docs-help-news-content-boundary.md`.
- If a tag mechanism is introduced, update or supersede the taxonomy stance in
  `adr/read-only-content-surfaces-in-rails.md` together with the change.
