# Development `/rails/info` Exposure Through Cloudflare Tunnel

Commit: `b7c56bbf0f87c9a71440abc363a7bb4682f90839`. The worktree had many unrelated uncommitted
changes. The change that affected this result is the uncommitted edit to
`config/environments/development.rb`.

## Observation

`log/development.access.jsonl` showed 5 `200` responses from `Rails::InfoController#properties`.
`log/development.log` showed CSP reports for `https://edit.umaxica.org/rails/info/properties` that
blocked the Cloudflare-injected `static.cloudflareinsights.com` beacon, so the page had been served
through the public tunnel. In the same log, 144 routing-error events covered other scanner paths
(`/.env`, `/.git/config`, `/info.php`, `/actuator/env`, and others). Each of those paths received a
404 response.

Cause: `config.consider_all_requests_local = true` made `Rails::InfoController` and the detailed
exception pages available to every requester.

## Change

`config.consider_all_requests_local = false` in `config/environments/development.rb`.
`.env` sets `TRUSTED_PROXIES=10.89.3.0/24`, so tunnel requests arrive from a non-loopback peer and
`request.local?` is false for them.

## Verification

- The user restarted the development server.
- The user opened `https://edit.umaxica.org/rails/info/properties` from outside the host. The page
  returned "For security purposes, this information is only available to local requests."
- The latest access-log entries for `/rails/info/properties` are `403` from `Rails::InfoController`.
- Not verified: `/rails/info/routes` and the detailed-exception-page behavior through the tunnel.
