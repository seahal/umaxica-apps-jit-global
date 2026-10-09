# Contact Auth Customer Canonicalization Note

This note records the naming decision for the contact-auth integration work.

## Status

Accepted on 2026-04-07.

## Decision

`customer` is the canonical name for the third auth subject used by the `com` surface.

The plan wording should not introduce a separate `client` subject name. Where the contact plan
previously said `client`, it should now say `customer`.

## Rationale

- The codebase already uses `customer` as the auth subject name.
- The `sign.com` surface and its controllers already speak in `customer` terms.
- Using one name removes ambiguity in claims, controllers, and tests.

## Consequences

- Future contact-auth work should use `customer` consistently.
- No new `client` subject should be introduced for this path.
