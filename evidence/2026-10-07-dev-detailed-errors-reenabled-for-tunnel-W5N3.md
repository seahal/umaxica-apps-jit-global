# Development Detailed Error Pages Re-enabled For Tunnel Requests

Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`. The worktree had many unrelated uncommitted
changes. The change that affected this result is the uncommitted edit to
`config/environments/development.rb`.

## Decision

The repository owner asked on 2026-10-07 for detailed error pages to be served in development even
to requests that arrive through Cloudflare Tunnel, after being shown the exposure recorded in
`evidence/2026-10-05-dev-detailed-errors-tunnel-exposure-Q4T8.md`. This reverses that record's
change and accepts its exposure.

## Change

`config.consider_all_requests_local = true` in `config/environments/development.rb`, with a comment
that states the accepted exposure and how to close it.

## Verification

A `bin/rails runner` script called `Rails.application.call` in the development environment with
`Host: www.umaxica.dev`, `X-Forwarded-Proto: https`, and `Accept: text/html`, after the change.

| Remote address | Path | Result |
|---|---|---|
| `10.89.3.9` | `/__nope__` | 404, 1,224,827 bytes, "Action Controller: Exception caught", 1,674 route rows |
| `10.89.3.9` | `/rails/info/routes` | 200, 1,168,950 bytes, 1,674 route rows |
| `127.0.0.1` | `/__nope__` | 404, 1,224,827 bytes, "Action Controller: Exception caught", 1,674 route rows |

Before the change, the running development server answered `/__nope__` on `Host: www.umaxica.dev`
from `127.0.0.1` with 404 and the 5,596-byte static page.

- Not verified: the running development server. It was stopped at the time of the check and reads
  the new value on its next start.
- Not verified: a request through the public tunnel.
- Not changed: Cloudflare Access coverage. On 2026-10-07 `www.umaxica.dev` and `jp.umaxica.dev`
  answered unauthenticated requests through the tunnel, so they serve these pages to anyone.
