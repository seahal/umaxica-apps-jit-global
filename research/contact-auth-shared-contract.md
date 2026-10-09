# Contact Auth Shared Contract

## Status

Accepted implementation note for the contact/auth integration track.

## Scope

This note defines the shared auth contract that contact surfaces must consume.

## Canonical actor types

- `guest`
- `anonymous_member`
- `identified_member`

## Surface rules

- `com` contact stays `guest`.
- `app` contact can be `guest`, `anonymous_member`, or `identified_member`.
- `org` contact can be `guest` or `identified_member`.

## Subject naming

- Use `customer` as the canonical name for the third auth subject.
- Do not use `client` for the same subject in code, claims, or tests.

## Route ownership

- Contact controllers stay under `core/*`.
- Auth surfaces stay under `sign/*`.
- Contact flow reads auth state only through shared auth helpers and token claims.

## Contract shape

- Auth claims must carry the subject type explicitly.
- Contact flow must not infer subject type from route prefixes alone.
- Cookie and host scope must remain isolated per surface.

## Implementation notes

- `customer` now exists in the OIDC client registry and token exchange path.
- `authorization_codes` now supports `customer_id` for `com` authorization flow.
- Contact flow changes should use this note as the contract baseline before any UI or controller
  rewrite.
