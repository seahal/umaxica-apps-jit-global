# Actor Session And Token Reader Removal

## Context

`adr/actor-current-facade.md` already made `Actor` the only current-context facade and rejected
`Current`, `Jumper`, `Acmeer`, and `Signer`. The remaining compatibility readers `Actor.session` and
`Actor.token` kept the ambiguous Rails-session name and exposed raw access-token claims as an
application-facing API.

## Decision

Remove `session` and `token` from `Actor::Context`.

Runtime code should use:

- `Actor.authn.login_public_id` for the current login/session public id.
- typed `Actor.authn` readers for authentication facts.
- `Actor.authn.access_claims` only at low-level auth or policy boundaries that still need raw
  access-token claims.

`ActorSupport` and authentication population now update related Actor fields with a single
`Actor.update(...)` call so `actor`, `actor_type`, and `authentication` are not exposed through
separate transient snapshots during normal lifecycle setup.
