# Signed Return Targets Only

## Status

Accepted (2026-05-25)

> **Amendment (2026-10-23):** for the first-party **RP** lane only, `pt` is replaced by the path-only
> `target_link_uri` carried in the RP's signed OIDC `state`
> ([RP OIDC state and return target](rp-oidc-state-and-return-target.md)). Auth's own signed `pt`, and
> the `nt` / `xt` lanes, are unchanged.

## Context

The authentication surfaces carry continuation destinations in the public `rt` parameter. Older code
accepted Base64-url encoded paths through `safe_path_from_encoded_rt`, then later added
`ReturnTargetToken` for signed, expiring, surface-bound, session-bound return targets.

Keeping both forms makes security review harder and leaves old helper names in circulation after the
signed-token mechanism exists. The Base64 form is not a security boundary and must not be treated as
authorization to redirect or resume a sensitive flow.

Signing a raw URL or raw path is also not enough. If the signed payload is itself a redirect URL,
then the redirect terminal still has to decide whether a host is acceptable. That keeps
open-redirect and cross-surface policy coupled to every consumer, and a future caller can
accidentally combine a valid signature with an unsafe external destination. A design that transports
`https://host/path` or arbitrary `/path` strings as the durable return target is therefore still
accident-prone.

## Decision

All new and changed `rt` handling must use signed return-target tokens issued and verified through
`ReturnTargetToken`.

The signed return-target payload must not be treated as a general URL container. The preferred
direction is an opaque continuation descriptor owned by the issuing flow: for example a symbolic
route key plus bounded parameters, or a server-side continuation record, resolved at the redirect
boundary into a local destination. Redirect terminals must fail closed unless the resolved
destination is explicitly local to the current surface or belongs to a separately reviewed provider
handoff/jump-link mechanism.

Internal application continuation and external link continuation must use separate public parameters
and separate verification paths. Ordinary internal continuation must not share one `rt` parameter
with external link handoff. The working direction is to introduce common concern helpers for both
classes of continuation, with names such as `inner_rt` for internal route continuation and
`outer_rt` for external link continuation, subject to final naming review before implementation.

Internal continuation should be encoded as a route descriptor instead of a URL string:

```ruby
{ route: "configuration", params: { ri: "jp" } }
```

After signature verification, the controller boundary resolves the descriptor through approved route
helpers for the current surface and then builds the final path. The descriptor must contain only a
bounded route key and bounded parameter set; it must not contain a host, scheme, port, userinfo,
fragment, or arbitrary URL/path string.

External continuation remains necessary, but it is not part of ordinary authentication `rt`
handling. It must use a separate parameter and a distinct, auditable boundary, preferably based on
named external destinations rather than caller-supplied FQDN strings. Any external redirect boundary
must parse and normalize URLs with Ruby's URI library, compare exact normalized origins against an
allowlist, reject userinfo/fragments/control characters, and fail closed.

`safe_path_from_encoded_rt` is deprecated and must be removed from code paths as they are touched.
Do not add new callers. If this term appears in docs, plans, notes, or code review context, treat it
as stale compatibility language: do not use it, and remove or replace it with signed-token handling.

Use one of these patterns instead:

- Verify an existing signed `rt` with `ReturnTargetToken.verified_return_to`.
- Use a narrowly named signed-only helper, such as `safe_path_from_signed_rt`, when controller-local
  flow/surface/session checks are already supplied by the authentication redirect concern.
- Issue public `rt` values with `ReturnTargetToken.issue` or a wrapper that delegates to it.

Do not introduce new call sites that pass verified return-target strings directly to
`redirect_to(..., allow_other_host: true)`. Cross-host redirects must live behind a distinct,
auditable boundary with exact origin allowlist checks; ordinary authentication `rt` continuation is
not that boundary.

## Consequences

- Legacy Base64 `rt` fallback is no longer an approved design direction.
- Signed URL/path payloads are a transitional implementation detail, not the target architecture.
  Future work should replace them with route descriptors or server-side continuation records before
  broadening redirect behavior.
- Internal and external continuation must be split before adding more redirect behavior. The exact
  public parameter names are deferred, but the split itself is accepted.
- Existing compatibility helpers may remain temporarily only where untouched flows still depend on
  them, but each touched call site should move away from `safe_path_from_encoded_rt`.
- Tests for migrated flows should assert that legacy Base64 `rt` input is rejected or ignored.
- Tests for the next return-target redesign should assert that ordinary `rt` continuation cannot
  redirect to an external host, even when the input is signed.
