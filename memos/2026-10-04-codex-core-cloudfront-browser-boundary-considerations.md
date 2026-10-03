# Core: Deferred CloudFront Authentication Cache and Browser Boundary Considerations

Discussion date supplied by the user: 2026-10-04

Status: Exploratory memo; implementation deferred.

Scope: Documentation only. No application, authentication, DNS, CDN, WAF, cookie, or rate-limit
configuration changes are authorized by this memo.

## Intent and decision status

We are considering whether Core should adopt the protections below in the near future, before
deploying the AWS Rails serving path. Preserve the CloudFront authentication-cache risk and the
related browser-origin, logging, and independent rate-limit concerns so they can be revisited.
This is a record of proposed directions and unresolved questions, not an implementation plan,
an accepted ADR, a completed security review, or evidence of correct production configuration.

The user requested that the CloudFront risk be retained without implementing it yet. The supplied
discussion also requests FQDN-scoped browser credentials and independent Rails/Cloudflare limits,
without runtime coordination. Later accepted clarifications retain the GET refresh prohibition and
establish the TanStack zero-cookie boundary in `adr/tanstack-start-zero-cookie-ui-origin-boundary.md`.
Other concerns remain exploratory; this memo does not override the accepted clarifications.

The discussion date and technical references below come from the supplied material. They do not
record a source consultation or deployment verification performed while saving this memo.

## Proposed architectural constraints

- Core's intended web presentation uses TanStack Start; native iOS/Android work belongs to Palm.
- Rails retains authentication, session/refresh-token processing, final authorization, and complex
  business logic. Signing and decryption secrets remain in the Rails authority.
- The browser independently requests Workers/TanStack content and Rails Core APIs. For Core
  user-facing work, Workers must not call or proxy Rails over VPC or public HTTP. Other surfaces,
  including Info, have separate contracts.
- The intended Core dashboard presentation belongs to TanStack. This decision imposes no dashboard
  implementation requirement on other surfaces. Core ownership is recorded in the 2026-10-03
  amendment to `adr/home-dashboard-authentication-boundary.md`. Common-data SSR is allowed, but its data sourcing
  remains outside this discussion and does not authorize Workers-to-Rails calls.
- The intended Rails serving path includes AWS CloudFront. Actual DNS and routing need inspection:
  DNS selects hosts; selecting paths on one host requires HTTP routing.
- Rails and Cloudflare limits remain independent, without shared counters, cross-provider
  authorization, callback dependencies, synchronized blocklists, or a common runtime limiter store.
- Preserve app/com/org and regional session boundaries without broadening cookies or origins.

These are discussion constraints for the future topology, not assertions about deployed behavior.
[The accepted route-ownership ADR](../adr/app-rails-edge-route-ownership.md) still describes
Rails-owned Core routes, including `GET /` during the current deployment stage.
[The accepted AWS ingress ADR](../adr/dos-and-firewall-controls-at-cdn-aws-edge-not-in-rails.md)
describes Cloudflare as DNS-only and assigns public HTTP protection to CloudFront/AWS WAF.
Any future Cloudflare protection must be assessed on the traffic that actually traverses it;
this memo does not supersede either ADR.

## CloudFront authentication-cache risk to retain

The supplied references describe shared-cache failure conditions: personalized responses,
authentication results, or `Set-Cookie` could be replayed to another browser. Cookie forwarding can
cause CloudFront to cache and replay `Set-Cookie`; a positive minimum TTL can override origin
`no-store` or `private` directives. These are risks to investigate, not deployment findings. [S1, S2]

Candidate protections for later review:

1. Inventory deployed Rails authentication, callback, logout, session, renewal, and personalized API
   routes by public host, path, and method. Do not assume one sensitive-route prefix.
2. Consider `CachingDisabled` or equivalent minimum/default/maximum TTL values of zero for those
   routes, alongside origin `no-store`. Authentication cookies in a cache key are not a substitute.
3. Review origin forwarding separately: required authentication cookies, `Origin`, `Sec-Fetch-*`,
   supported CSRF headers, and protocol query parameters. Review `Authorization` only for endpoints
   accepting it. Derive the public origin through reviewed host/proxy configuration. [S3]
4. Preserve separate `Set-Cookie` fields and attributes, including renewal cookies; do not combine
   them into a comma-separated field.
5. Inspect default and ordered behaviors, redirects, custom errors and error-cache TTLs, and other
   intermediary caches. Zero object-cache TTL alone does not establish safety for every response.
6. Separate public static assets from sensitive paths. Asset-like suffixes and fallback matches must
   not make authentication, personalization, or credential mutation cacheable.
7. Resolve this within CloudFront/AWS configuration and Rails responses, without introducing a
   Workers-to-Rails forwarding function.

Possible future verification scenarios, all unexecuted:

- Alternate user A, user B, and anonymous requests to the same sensitive URL; inspect bodies,
  redirects, authorization results, and cookies for cross-browser reuse.
- Exercise expired access with valid refresh at the intended Rails continuation boundary; verify
  that renewal reaches only that browser and is used on its next request.
- Inspect callbacks, sign-out, and authentication failures for shared-cache hits.
- Exercise unmatched and encoded paths, query strings, trailing slashes, HEAD, and error responses.
- Inspect required headers across the real CDN/origin path and reject silent weakening when metadata
  is missing.
- Inspect all three TTL values and custom-error settings. A successful request or absent `Age`
  header alone is insufficient evidence.

## Cookie destination and browser request source

These controls address different boundaries:

- **Destination:** consider host-only authentication cookies without `Domain`. A `__Host-` name
  additionally requires `Secure` and `Path=/` in supporting browsers; set `HttpOnly` explicitly.
  This memo does not authorize renaming production cookies. [S4]
- **Source:** for ordinary protected browser mutations and any approved renewal boundary, consider
  the exact intended origin: scheme, hostname, and effective port. Sibling same-site hosts do not
  become trusted automatically. Avoid suffix, wildcard, and substring matching. [S5, S6]

For one public origin, assess that configured origin. If the browser presentation and Rails API
hosts differ, review an endpoint-specific source/destination pair; a blanket same-origin rule could
block the intended client. Do not widen cookie `Domain` to solve that problem. The concrete pair
remains unknown.

A host-only cookie can still accompany a request initiated by another site to its destination host,
subject to browser rules. `__Host-` restricts the cookie destination, not the initiating origin.
`SameSite` is not exact-origin enforcement, and cookies do not isolate ports or URL paths. [S4]

Before implementation, inspect the pinned Rails implementation and tests. The supplied Rails
reference describes Fetch Metadata strategies that may accept same-site requests; listing one
`trusted_origins` entry must not be assumed to remove that acceptance. [S6]

Review missing metadata, `Origin: null`, conflicting headers, foreign ports, and redirects.
Same-origin GET may omit `Origin`; consider Fetch Metadata and legitimate navigation rather than
requiring that header indiscriminately. These signals supplement session validation and are not
credentials. OAuth/OIDC callbacks need narrowly scoped existing protocol validation, rather than
a generic deny rule that breaks callbacks or exemptions spanning an entire controller tree.

## GET-triggered renewal risk and retained prohibition

The accepted 2026-10-03 clarification in `adr/app-rails-edge-route-ownership.md` prohibits GET
refresh for both `auth_refresh` and `feel_refresh`. Access reads and existing confirmed-invalid-cookie
recovery remain distinct. The questions below retain historical discussion context only and do not
propose an exception to that prohibition.

The supplied Rails reference describes `verified_request?` accepting GET and HEAD before ordinary
CSRF checks. Rotation in a GET callback therefore does not automatically receive Fetch Metadata
protection. This is a framework question to verify against the pinned revision, not an exploit
finding. [S7]

An induced request might carry a qualifying cookie to its correct destination, consume refresh
generation N, and cause a concurrent legitimate request using N to be classified as replay.
Availability and session integrity could suffer even if the initiating page cannot read the response.
`SameSite=Lax` ordinarily withholds cookies on cross-site image/subresource requests but can include
them on top-level safe navigation; sibling requests may be same-site. `Strict` also does not establish
exact-origin isolation. [S4]

Reconcile any implicit renewal proposal with `generic/absolute-rules.mdc` and current authentication
ADRs before approval. Candidate questions include:

- How is credential mutation gated before rotation, even if the outer method is GET?
- How is renewal confined to its intended API contract, excluding HEAD, OPTIONS, public assets,
  and known speculative loads without depending on detection of every prefetch?
- How can ordinary public top-level navigation remain free of credential mutation?
- How are unknown or conflicting request contexts resolved without rotation or silent fallback?
- How are credentials validated before consumption and concurrent renewal/revocation coordinated
  inside Rails? Client-only coordination cannot guarantee correctness.
- How are absolute session lifetime, authentication time, and step-up freshness preserved?

Neither transparent GET refresh nor a periodic frontend POST timer is approved here.

## XSS, logs, and stale browser data

Rails ownership of secrets does not neutralize script running inside the legitimate Core page.
Executable user-controlled content could request data and perform session-authorized actions without
reading an `HttpOnly` cookie. Exact-origin and Fetch Metadata checks would see the legitimate
origin. [S4, S8]

Future review should cover rendering text as text, HTML/Markdown sanitization, URL handling, raw HTML
insertion, an application-appropriate restrictive CSP, and Rails resource authorization. Preserve
existing step-up requirements without treating them as a universal repair for active XSS.

Consider these output and lifecycle boundaries separately:

- Disable raw authentication-cookie logging at CloudFront; cookie logging may include cookies not
  forwarded to the origin. [S1]
- Inspect CloudFront/WAF sampling, Rails logs, error reporting, and tracing independently. Avoid
  `Cookie`, `Authorization`, token responses, and unfiltered callback URLs/parameters. Redaction
  at one layer does not establish redaction at another.
- Retain audit identifiers, timestamps, outcomes, and correlation IDs without bearer secrets.
- On logout or account-context changes, cancel or discard stale private requests and clear relevant
  browser query state. Keep refresh/access credentials out of TanStack Query and web storage.
- If Rails and Workers own different paths on one FQDN, `__Host-` with `Path=/` can send cookies to
  Workers-owned paths too. The accepted TanStack boundary requires removal of the entire `Cookie`
  header before the UI origin and every UI-origin `Set-Cookie` before the browser. Selective
  minimization is insufficient; Rails API cookies retain their separate contract.

## Independent rate limits and residual risk

The requested direction is stricter, independently enforced limits. Cloudflare protects only traffic
through its applicable layer; Rails/AWS protects the Rails path independently. Production Rails
instances still need their own shared authoritative semantic limiter, as required by the accepted
AWS ingress ADR. Independence from Cloudflare does not imply a separate quota per Rails process.

Avoid count/blocklist synchronization and cross-provider checks. One provider's outage should not
bypass or disable the other provider's limiter. Select thresholds from endpoint cost and measured
legitimate bursts, accounting for account lockouts, shared NATs, and overly small global quotas.

Smaller quotas do not replace origin access controls or absorb arbitrary volumetric traffic.
An exposed origin can bypass CDN protections. Retain the accepted AWS ingress ADR and revisit it
explicitly before any future relaxation; independent limiting does not authorize origin exposure.

## Open questions and promotion

Before making this actionable, inspect the actual Rails revision/tests, public route ownership,
CloudFront behaviors, cookie settings, and origin/Fetch Metadata handling. Resolve the serving
topology and GET mutation conflict explicitly. Existing Rails authentication remains the baseline;
a new BFF or token store is not proposed.

Promote agreed future work to `plans/backlog/` when its scope is concrete. Record approved decisions
in the relevant ADRs only after approval. Stable operational documentation belongs in `docs/` after
implementation. This memo authorizes none of those implementation steps.

## References supplied with the discussion

These links are retained for future verification. Rails edge documentation moves; use the project's
pinned revision before implementation. No runtime or CDN acceptance tests were executed for this
documentation-only change.

- [S1] [AWS: Cache content based on cookies](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Cookies.html)
- [S2] [AWS: Use managed cache policies](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html)
- [S3] [AWS: Control origin requests with a policy](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/controlling-origin-requests.html)
- [S4] [MDN: Set-Cookie](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie)
- [S5] [OWASP: CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)
- [S6] [Rails: RequestForgeryProtection::ClassMethods](https://edgeapi.rubyonrails.org/classes/ActionController/RequestForgeryProtection/ClassMethods.html)
- [S7] [Rails: verified_request?](https://edgeapi.rubyonrails.org/classes/ActionController/RequestForgeryProtection.html#method-i-verified_request-3F)
- [S8] [React: dangerouslySetInnerHTML](https://react.dev/reference/react-dom/components/common#dangerously-setting-the-inner-html)
