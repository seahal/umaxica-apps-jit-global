# Redirect Target Lanes: pt, nt, xt

## Status

Accepted (2026-05-26)

## Context

Older redirect code mixed path returns, flow navigation, and external handoff under names such as
`rt`, `return_to`, and helper-specific safe redirect methods. That made priority and host policy
hard to audit.

`adr/signed-return-targets-only.md` improved the older `rt` design by requiring signed return target
tokens, but it still left a transitional model where signed path strings could circulate through
general return-target helpers. Signing lowered tampering risk, but it did not make target type,
priority, or external-origin policy structurally obvious at every redirect boundary.

## Decision

Redirect targets use three structurally separate lanes:

- `pt` carries only local path targets.
- `nt` carries navigation registry keys for internal flows.
- `xt` carries named allowlisted external targets.

`pt` is path-plus-query only and is never an external URL carrier. It rejects schemes, hosts,
protocol-relative URLs, userinfo, fragments, control characters, encoded control characters, encoded
slash or backslash host escapes, backslashes, executable schemes, blank values, and nil.

`nt` is a navigation target, not an "internal target". It is resolved from a symbol or explicit
string key through a registry. Raw paths and raw URLs are invalid `nt` input. Flow-specific scopes
may restrict which registry keys are legal.

`xt` is the only external redirect lane. It must resolve through a registry or explicit allowlist.
Using `allow_other_host: true` outside the `xt` facade is forbidden.

Controller concerns expose only a thin facade. Validation, normalization, registry resolution, and
priority selection live in `Redirects::*` service objects and return `Redirects::TargetResult`.

Internal priority is explicit:

1. controller-declared `nt`;
2. signed/session `nt`;
3. signed `pt`;
4. raw `pt` if it validates as a path target;
5. explicit default path.

Security-dangerous upper-priority values fail closed. Missing values may continue to the next
priority entry. `xt` is never a fallback in this chain.

## Consequences

This is a breaking security refactor. Legacy `rt` and `return_to` behavior is not preserved as a
public compatibility contract. Remaining legacy names must either be migrated to `pt`, `nt`, or
`xt`, or be isolated with a documented reason until the owning flow is rebuilt.

`adr/signed-return-targets-only.md` remains useful history for why unsigned and Base64 return
targets are rejected, but this ADR supersedes its deferred naming direction. The accepted public
names are `pt`, `nt`, and `xt`.

OIDC protocol fields named `redirect_uri` are not renamed, because that name is part of the
protocol. They must still resolve through the OIDC client registry and the `xt` boundary before any
cross-host redirect.

Jump-link redirects remain a reviewed external redirect feature, but the redirect operation itself
must go through the `xt` facade.

The implementation adds an audit command and regression tests so new direct parameter redirects and
new direct `allow_other_host: true` uses fail review.

## Amendment Reference (2026-10-12)

The statement above that Jump-link redirects remain a reviewed external redirect feature is narrowed
by the "Deprecation of Jump RT External Destinations" amendment in
`adr/secure-jump-link-redirector.md`: Jump RT external destinations are deprecated for new use, Jump
RT carries approved first-party cross-origin handoffs, and `xt` owns external website destinations.
