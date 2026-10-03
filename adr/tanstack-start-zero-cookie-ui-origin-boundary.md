# TanStack Start Zero-Cookie UI Origin Boundary

## Status

Accepted (2026-10-03). Implementation and deployment verification remain deferred.

Supersedes the Core UI-origin and SSR portions of
`adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md` for TanStack Start.
Rails credential authority, RP issuer/audience/transport binding, and other surfaces' contracts
retain their existing governing ADRs.

## Context

The previous Next.js decision established a zero-cookie UI origin but deferred the TanStack SSR
boundary. Core's TanStack presentation and the `auth_*` / `feel_*` / reserved `continuity`
vocabulary must preserve that separation and the existing GET refresh prohibition.

## Decision

TanStack Start inherits the existing zero-cookie UI-origin invariant:

- No `Cookie` request header reaches the TanStack Start UI origin. The serving boundary strips
  the entire header on Core UI/page routes, including SSR and assets, regardless of cookie name.
- TanStack Start must not emit `Set-Cookie`. The serving boundary removes every UI-origin
  `Set-Cookie` response field before the response reaches the browser.
- TanStack holds no browser credential, refresh handle, signing/decryption secret, or client secret.
  The exclusion covers `auth_*`, `feel_*`, future `continuity`, RP cookies, and every other cookie.

`auth_access`, `auth_refresh`, and `auth_dbsc` are Rails/browser authentication transport slots.
`feel_access`, `feel_refresh`, and `feel_dbsc` are Rails/browser Preference credential transport
slots, never Xper/TanStack surface cookies. `continuity` is a reserved, unimplemented name; its
future handling belongs at the Rails/browser boundary and grants TanStack no credential access.
This decision performs no cookie migration or continuity implementation.

The browser independently requests Core UI content and explicit Rails APIs. The Rails API serving
path preserves cookies required by its existing contracts and separate Rails `Set-Cookie` fields,
including recovery deletions. UI stripping must not be applied to Rails responses. Routing retains
the no-Workers-to-Rails-call/proxy decision in `adr/core-canonical-public-host.md` and accepted AWS
ingress restrictions. This decision introduces no Worker forwarding function.

Core renders public/default UI without user-bound SSR. Preference representation is requested by
browser JavaScript through an explicit Rails `/api/v0/...` contract after hydration. TanStack SSR
never reads `feel_*` or other credentials to personalize initial rendering. Changing this invariant
requires a new ADR explicitly approving a different UI-origin boundary. Non-user-bound common-data
SSR remains allowed; its sourcing is outside this decision and does not authorize calls to Rails.

GET navigation may read and validate `auth_access` or `feel_access` under existing endpoint
contracts. It must never consume `auth_refresh` or `feel_refresh` to issue new access credentials,
rotate tokens, or extend credential lifetime. Preference naming creates no exception. HEAD remains
non-rotating under the existing recovery contract.

Confirmed invalid or expired cookie detachment/deletion on GET remains permitted only under
`adr/invalid-browser-credential-recovery.md`. Recovery is distinct from refresh and issues no
replacement credential. System failures remain errors rather than anonymous recovery. Existing
narrowly validated OIDC protocol callbacks retain their separate protocol contract.

This UI decision applies only to Core and imposes no dashboard framework, rendering, or
implementation-location constraint on other surfaces.

## Verification status

Deployment must demonstrate complete UI request/response cookie stripping, preservation of required
Rails cookies, and actual route ownership. Rails checks must distinguish GET/HEAD access reads and
recovery deletion from refresh consumption. These runtime and deployment checks have not been
executed for this documentation-only decision; existing route rollout gates remain in force.

## Related

- `adr/core-canonical-public-host.md`
- `adr/app-rails-edge-route-ownership.md`
- `adr/invalid-browser-credential-recovery.md`
- `adr/home-dashboard-authentication-boundary.md`
- `memos/2026-10-04-codex-core-cloudfront-browser-boundary-considerations.md`
