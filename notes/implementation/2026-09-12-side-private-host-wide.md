# Side Private Host `wide` Implementation Notes

## Context

- Request: rename Side's private development and Tunnel origin hosts from
  `side.*.localhost` to `wide.*.localhost`.
- Related decision: `notes/implementation/2026-09-11-side-public-host-www-jp.md` established
  `www-jp.umaxica.{app,com,org}` as Side's public host family while retaining the former private
  names.

## Decisions Made During Implementation

- Decision: keep the public `www-jp.umaxica.{app,com,org}` host family unchanged and rename only
  Side's private origin family to `wide.{app,com,org}.localhost`.
  - Why: the public host and private Tunnel origin serve different routing roles, and the request
    explicitly names the private origin change.
  - Alternatives considered: rename the Rails `Side` namespace and route helper prefix. Rejected
    because `wide` is an origin hostname change, not a product-boundary rename.
- Decision: remove the former private names rather than support both families.
  - Why: the requested operation is a rename, and retaining aliases would conceal stale Tunnel or
    OIDC configuration.
- Decision: publish Dev Container Rails as `127.0.0.1:3001 -> core:3000` while retaining container
  port `3000` for Tunnel and inter-container traffic.
  - Why: host port `3000` must remain available for future host-native Rails runs without changing
    the private origin contract inside the Compose network.
- Decision: admit both ports `3000` and `3001` for the `wide.*.localhost` family in development
  Host Authorization.
  - Why: Tunnel requests use the container port while host-browser requests carry the published
    host port in the `Host` header.

## Review Notes

- Static checks: no active `side.{app,com,org}.localhost` references remain outside historical
  notes, plans, and evidence; Ruby syntax, YAML parsing, whitespace validation, and the engine-free
  Compose host-port contract test were run.
- Tests not run: Rails tests were blocked before boot because the host bundle does not contain the
  Git-sourced Rails checkout. No dependency installation was performed.
- External follow-up: recreate the remotely managed Tunnel routes with
  `http://wide.{app,com,org}.localhost:3000` origins.
