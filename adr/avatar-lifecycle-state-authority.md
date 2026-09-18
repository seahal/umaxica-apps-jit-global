# Avatar Lifecycle State Authority

## Status

Accepted

## Date

2026-07-03

## Context

Content DB implementation must not define Avatar lifecycle authority by accident. Avatar state must
be owned before content, moderation, and feed behavior start depending on it.

## Decision

The avatar database is the authority for the current lifecycle state of an Avatar.

The current state is stored through a reference table, `avatar_lifecycle_states`, and
`avatars.lifecycle_state_id` points to that table. Rails integer enums and PostgreSQL enums are not
used for lifecycle authority.

Initial lifecycle states are:

- active
- suspended
- archived
- banned
- deleted

Avatar DB provides the current state. Content and moderation systems decide whether historical
content is visible, hidden, deleted, or excluded from ranking. Avatar lifecycle state is an input to
those decisions, not the content-side execution mechanism.

Posting-time `avatar_public_id`, handle, moniker, and display-state snapshots belong to the content
database or content read model. Avatar DB must not create actor snapshot tables.

Lifecycle transitions are performed through an application service that validates the transition,
validates actor authority, updates `avatars.lifecycle_state_id`, and records
`avatar_lifecycle_events`. Invalid transitions raise; silent fallback is forbidden.

The v1 transition policy is service-local. The minimum allowed transitions are:

- `active -> suspended`
- `suspended -> active`
- `active -> archived`
- `archived -> active`
- `active -> banned`
- `suspended -> banned`
- `archived -> banned`
- `active -> deleted`
- `archived -> deleted`
- `suspended -> deleted`
- `banned -> deleted`

`deleted` is terminal. `banned -> active` is not owner-authorized and is not in the v1 allowed
transition map.

`avatars.avatar_status_id` remains a legacy compatibility column until a later retirement slice.
Lifecycle reads must prefer `avatars.lifecycle_state_id`.

## Consequences

Content and moderation code consume Avatar state as policy input while keeping content display,
deletion, and ranking actions in their own domains.

Existing historical `posts` placement in avatar migrations remains a legacy UGC violation. New
content tables, feed material, reactions, media, comments, and actor snapshots must not be added to
the avatar DB.

## Related

- `docs/architecture/umaxica-v1-architecture-lock.md`
- GH issue #835
