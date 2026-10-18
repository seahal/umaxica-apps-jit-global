# Development CSP Reports From Cloudflare Tunnel

## Status

Accepted on 2026-10-02.

## Context

The development server is reachable from the public internet through a Cloudflare Tunnel (for
example `edit.umaxica.org`). Requests that pass through Cloudflare can be rewritten at the edge.
The most visible rewrite is Cloudflare Web Analytics, which injects
`https://static.cloudflareinsights.com/beacon.min.js` into HTML responses.

Injected content has no CSP nonce and its origin is not allow-listed, so the browser blocks it and
sends a report to the surface's `/csp-violation-report` endpoint. Internet scanners that crawl the
tunnel hosts produce a steady stream of such reports. On 2026-10-02, `log/development.log`
contained `security.csp_violation.reported` events for
`https://edit.umaxica.org/rails/info/properties` with the blocked URI
`https://static.cloudflareinsights.com/beacon.min.js/...`, caused by a scanner request.

These reports describe content that the Cloudflare edge added. They do not describe content that
the application emitted, so the application policy needs no change to address them.

## Decision

In the development environment, CSP violation reports caused by Cloudflare Tunnel are treated as
expected noise and may be ignored. Developers do not investigate them and do not widen the CSP to
silence them.

A report falls under this decision when all of the following hold:

- It was recorded by a development server.
- `document_uri` is on a host served through the Cloudflare Tunnel.
- The blocked resource was injected by the Cloudflare edge, for example a `blocked_uri` on
  `static.cloudflareinsights.com` or another Cloudflare-owned origin.

Reports outside that scope still need investigation. Examples include reports from production,
reports from `localhost` hosts, and reports whose blocked resource comes from application code or a
dependency.

The CSP is never relaxed to allow Cloudflare-injected resources. The report pipeline also keeps
recording these events. This decision only states that they need no follow-up.

## Consequences

- Development triage time goes to reports that reflect application behavior.
- The production CSP and the report endpoint stay unchanged.
- A blocked Cloudflare resource in a report is not, on its own, evidence of a CSP defect.
- The CSP report itself is not a security problem. If it shows that a scanner reached a sensitive
  development page, that exposure still needs separate handling.

## Related

- `adr/csp-and-permissions-policy.md`
- `adr/csp-violation-report-route-naming.md`
