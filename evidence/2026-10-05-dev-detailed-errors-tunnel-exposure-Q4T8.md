# Development Detailed Error Pages Exposed Through Cloudflare Tunnel

Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`. The worktree had many unrelated uncommitted changes. The change that affected
this result is the uncommitted edit to `config/environments/development.rb`.

## Observation

`log/development.log` between 2026-10-05 01:00 and 03:14 UTC held 234
`diagnostic.routing_error.authority` events for scanner paths such as `/.env`, `/.git/config`,
`/actuator/env`, and `/graphql`, on `umaxica.com` (117), `umaxica.app` (86), `umaxica.org` (30), and
`auth.umaxica.org` (1).

`config.consider_all_requests_local` was `true` at this commit. The `false` value recorded in
`evidence/2026-10-02-dev-rails-info-tunnel-exposure-K7Q2.md` was an uncommitted edit and was no
longer present.

`curl -H "Host: umaxica.com" http://127.0.0.1:3000/.env` against the running development server
returned `404` with a 1,170,236-byte "Action Controller: Exception caught" page that contained the
route table.

## Change

`config.consider_all_requests_local = false` in `config/environments/development.rb`, with a comment
that states the reason.

## Verification

A `bin/rails runner` script called `Rails.application.call` in the development environment with
`Host: umaxica.com` and `X-Forwarded-Proto: https`, before and after the change.

| Remote address | Path | Before | After |
|---|---|---|---|
| `10.89.3.9` | `/.env` | 404, 1,180,859 bytes, debug page, 1,611 route rows | 404, 5,596 bytes, no debug page |
| `10.89.3.9` | `/rails/info/routes` | 200, 1,124,736 bytes, 1,611 route rows | 403, 83 bytes |
| `127.0.0.1` | `/.env` | 404, 1,180,859 bytes, debug page | 404, 5,596 bytes, no debug page |

- Not verified: the running development server, which keeps the old value until it is restarted.
- Not verified: a request through the public tunnel.
- Not changed: Cloudflare Access coverage of the apex hosts, which is outside this repository.
