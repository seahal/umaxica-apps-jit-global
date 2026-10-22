# Redirect Targets

> **Partially superseded by Identity Authority inversion:** Redirect vocabulary in this document
> remains useful, but redirects are navigation only. They are not credential ceremony results and
> must not carry authentication, account, token, or step-up freshness results. `acme/www` is the
> Session, Token, Account, Preference, Authorization, and downstream-token Authority. `sign/id` is
> ceremony-only.

Redirect targets are split into three separate lanes. These names are public contract names and
controller/service code should use them consistently.

- `pt` means path target. It is for local path returns such as post-login, post-update, cancel, and
  retry destinations. It accepts only path plus query.
- `nt` means navigation target. It is for internal flow and screen transitions. It accepts registry
  keys, not caller-supplied URLs or arbitrary paths.
- `xt` means external target. It is for handoff to another origin. It accepts only named or
  explicitly allowlisted external destinations.

Do not use `it` as an abbreviation for internal target. The internal flow abstraction is `nt`
because it is a navigation target.

## Required Gateway Selection

**Accepted policy revision: 2026-10-22; runtime implementation pending.** This section records the
required Rails navigation policy, not a claim that all existing callers enforce it. See the
[redirector ADR amendment](../../adr/secure-jump-link-redirector.md#amendment-required-jump-and-away-selection-2026-10-22).

Rails MUST classify the final destination against the initiating surface before selecting a gateway:

| Initiating surface and final destination | Required route |
| --- | --- |
| Same origin (scheme, host and effective port) | Validated local path; direct navigation is permitted. |
| Different subdomains of the same registered application domain, such as `www.umaxica.app` to `auth.umaxica.app` | Jump through `https://jump.umaxica.net`; an approved directed edge is also required. |
| Different TLDs, such as `www.umaxica.app` to `www.umaxica.com` | Away through `https://away.umaxica.net`, including when both sites are first-party. |
| Any other external website | Away through `https://away.umaxica.net`, subject to explicit destination authorization. |

Subdomain changes remain separate trust boundaries even when both hosts are owned by Umaxica.
Sharing only a TLD is insufficient to qualify for Jump: `umaxica.app` and `example.app` are separate
domains. Classification MUST use normalized, explicitly registered application domains and exact
origin matching, rather than substring tests or a guessed last-two-label domain. Scheme or port
changes outside the approved HTTPS origin registry MUST be rejected.

The classifier uses the final destination, not the gateway's own `.net` domain. Sending a
same-domain handoff to Jump therefore does not recursively classify the gateway hop as an Away
navigation. Gateway selection MUST be server-owned; caller parameters cannot select or override it.

The common `xt` facade MUST validate the chosen gateway against exactly the two HTTPS root origins
above, including scheme and effective port. It MUST reject userinfo, alternate hosts or ports,
suffix lookalikes, and caller-supplied gateway URLs. Destination paths, queries and authorization
remain independently validated; an allowlisted gateway does not make its destination trusted.

Rails `allow_other_host` controls `redirect_to`, not URL generation or `link_to`, and is a boolean
bypass of the same-host check rather than a host allowlist. `allow_other_host: true` MUST be confined
to the common facade after exact gateway-origin validation. Cross-origin navigation emitted by
Rails through links, redirect responses or browser navigation targets MUST use the selected gateway;
generating an absolute URL with a Rails helper does not exempt it from this policy. Protocol fields
such as a registered OIDC `redirect_uri` continue to identify the final receiver; they MUST NOT be
rewritten to name a gateway.

The selected gateway MUST authorize its final destination independently. Same-domain Jump still
requires the approved source/destination graph; cross-TLD Away does not grant cross-surface session,
identity or state sharing. Existing signed-token, receiver verification, CSRF, state, nonce, PKCE,
authentication and authorization requirements remain in force. This navigation policy does not
convert cross-origin POSTs or server-to-server HTTP calls into redirect-based transport; their
method, payload and security contracts require separate review.

Until Away's authorization and wire contract is implemented, navigation requiring Away MUST fail
closed. It MUST NOT fall back to a direct destination redirect or Jump. Existing direct cross-host
callers and the single-gateway implementation require follow-up implementation; this documentation
revision changes no Rails, Jump or Away runtime behavior.

## Path Targets

`pt` is path-plus-query only. The path target resolver rejects:

- schemes and hosts, including `https://evil.example` and `http://evil.example`;
- protocol-relative URLs such as `//evil.example`;
- backslashes, including `/\evil.example` and `\evil.example`;
- control characters, CRLF, NUL, and encoded control characters;
- encoded slash or backslash host escapes such as `%2f` and `%5c`;
- userinfo;
- fragments;
- blank or nil values;
- executable schemes such as `javascript:` and `data:`.

Allowed examples:

- `/dashboard`
- `/dashboard?tab=security`
- `/settings/security`
- `/sign/out/complete?x=1`

Rejected `pt` values produce a `Redirects::TargetResult` with `failure_reason` and, when a value was
present, `unsafe_value_digest`. Dangerous values must not be silently converted to the default path.

## Navigation Targets

`nt` resolves through `Redirects::NavigationTargetResolver`.

The registry owns the mapping from key to path helper. A controller or flow may pass a scope so only
the keys valid for that flow can resolve. Raw paths and absolute URLs are invalid `nt` input even if
they point at the same application.

Current baseline registry keys include:

- `checkpoint`
- `selector`
- `dashboard`
- `configuration_security`
- `signed_out`
- `home`

Registry entries must resolve to `pt`-valid paths. A registry entry that resolves to an external URL
is invalid and must fail closed.

## External Targets

`xt` resolves through `Redirects::ExternalTargetResolver`.

External redirects are allowed only after explicit allowlist or registry resolution. `xt` rejects
userinfo, fragments, control characters, unallowlisted origins, and HTTP downgrades except for
development/test localhost-style origins. Path joins must stay inside the selected origin, so a path
such as `//evil.example` is invalid.

When merging query parameters for an external redirect, do not relay redirect-like parameters from
the caller. The resolver strips dangerous keys including:

- `redirect_uri`
- `return_to`
- `redirect_to`
- `rt`
- `pt`
- `nt`
- `xt`
- `next`
- `continue`
- `url`

`allow_other_host: true` MUST appear only inside the common `xt` facade after the gateway validation
described above. Controllers and other callers MUST delegate cross-origin navigation to that facade.

## Priority

Internal redirect priority is explicit:

1. controller-declared `nt`;
2. signed/session `nt`;
3. signed `pt`;
4. raw `pt` when it validates as a path target;
5. explicit default path.

`xt` is not part of the internal priority chain. Actions that hand off to another origin must call
the external target resolver directly and must not let an external target override `pt` or `nt`.

Security-dangerous upper-priority values fail closed. Benign missing values may continue to the next
priority entry and eventually to the explicit default path.

## Controller Use

Controllers should use the facade methods from `Common::Redirect`:

- `redirect_to_pt(default: dashboard_path)`
- `redirect_to_nt(:selector)`
- `redirect_to_xt(:rp_app, path: "/signed-out")`
- `redirect_to_xt_url(url, allowed_urls: [...])`
- `resolve_redirect_target(priority: [...], default: dashboard_path)`

Do not redirect directly to a raw request parameter.

## Legacy Names

Legacy names such as `rt`, `return_to`, `redirect_to`, `redirect_uri`, `next`, and `continue` are
not the public internal-return contract. Existing OIDC protocol fields named `redirect_uri` remain
protocol inputs, but they must resolve through the OIDC client registry and external-target boundary
before any cross-host redirect.

Jump URL `?rt=` is the only allowed replacement for legacy `return_to` handoff across a jump
boundary. The `rt` value is never a raw URL. It must be a signed, short-lived redirect token with
issuer, purpose, and audience validation. Raw `return_to`, raw `redirect_uri`, and raw external URLs
must not be copied into `?rt=`.

Remaining raw `rt` and `return_to` uses in sign-in, sign-up, step-up, logout, social, and jump flows
are migration debt. They must either issue a signed Jump URL `rt` token or be isolated with an
owning-flow reason until that flow is rebuilt.

## Audit

Use:

```bash
bin/audit_redirects
```

The audit reports direct parameter redirects, direct `allow_other_host: true`, legacy `rt` /
`return_to` reads, and old safe-return helper names. These reports do not establish that the required
gateway policy is implemented. Existing direct
`allow_other_host: true` callers remain implementation gaps; enforcement tests for the revised
Jump/Away policy are pending with the runtime work.
