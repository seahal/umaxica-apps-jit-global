# Acme / Sign / Core / Base / Port Recap

## Context

The accepted naming recap fixes the architecture vocabulary as Acme, Sign, Core, Base, and Port. The
withdrawn names Deck and Bare are not part of the target architecture.

## Observed

- Existing ADRs and docs still contain a Rails-only identity authority model centered on `acme/www`
  and `sign/id`.
- The new accepted model makes Acme the only IdP / Authorization Server.
- Sign becomes a special RP, not an IdP.
- Core becomes the Next.js web RP/BFF.
- Base is a new Rails foundation/control-plane subdomain split out of the older Core concept.
- Port is a native bearer-token API Resource Server with `aud = port-api`.
- Browser sessions stay on Core through `__Host-core_sid`; bearer tokens stay server-side.
- Core and Base do not share cookies or sessions. The common identity key is Acme `iss + sub`.

## Why It Matters

The old `acme/www` and `sign/id` authority language can lead implementers to keep a Rails-only
identity model or to treat Sign as an IdP-adjacent authority. The new model separates IdP, web BFF,
Rails foundation, and native API responsibilities more cleanly.

## Open Questions

- Final production hostnames for Acme, Sign, Base, and Port.
- Final Port URL shape.
- Whether Core-to-Base APIs need distinct `core-api` or `base-api` audiences.
- The migration sequence from current Rails code to separate Acme/Core/Base/Port components.

## Promotion Candidate

The stable decision is recorded in `adr/acme-sign-core-base-port-boundary.md`. The stable
architecture reference is `docs/architecture/acme-sign-core-base-port.md`. Implementation follow-up
is tracked in GH issue #829.
