# CSP Violation Report Route Naming

## Status

Accepted (2026-06-13)

## Context

Each public surface exposes a browser CSP report endpoint at `POST /csp-violation-report`. The route
was considered for shorter internal resource naming, especially changing:

```ruby
resource :csp_violation_report, only: :create, path: "csp-violation-report"
```

to:

```ruby
resource :csp, only: :create, path: "csp-violation-report"
```

The public URL is already the browser-facing CSP report URI and should not change.

## Decision

Keep the explicit `csp_violation_report` resource name for now.

Do not rename the route resource to bare `csp`. The endpoint receives CSP violation reports; it does
not create or mutate a generic CSP resource. The longer internal name is more accurate and continues
to resolve naturally to each surface's `CspViolationReportsController`.

If route helper shortening is reconsidered later, prefer a name that preserves the report semantics,
such as `csp_report`, and keep the public path as `/csp-violation-report`.

## Consequences

- The public endpoint remains `POST /csp-violation-report`.
- Existing route helpers may remain long, such as `sign_app_csp_violation_report_path`.
- Future routing cleanup must not use `resource :csp` for this endpoint merely to shorten helper
  names.
- Any future rename must keep the surface-local controllers and explicit report semantics intact.

## Related

- `adr/csp-and-permissions-policy.md`
- GH issue #645
