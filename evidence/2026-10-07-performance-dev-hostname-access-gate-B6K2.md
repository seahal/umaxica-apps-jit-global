# `performance.umaxica.dev` Published Behind Cloudflare Access

Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`. The worktree had many unrelated uncommitted
changes; none of them affects this result, which measures Cloudflare-account configuration.

Follows `evidence/2026-10-08-dev-hostname-access-probe-H3W7.md`, which left the `000` response of
`performance.umaxica.dev` undetermined.

## Cause of the earlier `000`

Until 2026-10-07T16:03Z, `1.1.1.1` and `dns.google` answered `NXDOMAIN` for the `A`, `AAAA`, and
`CNAME` records of `performance.umaxica.dev`. The hostname had no DNS record. The repository owner
then added the published hostname in the Cloudflare account, with the origin
`http://performance.core.dev.localhost:3000`.

A `dig` without `@1.1.1.1` inside the Dev Container answers `10.89.4.4` for every `.dev` hostname,
from the `core` aliases in `.devcontainer/compose.yaml`, and does not measure public DNS.

## Method

From the Dev Container at 2026-10-07T16:06Z, with public DNS forced:

```bash
ip=$(dig @1.1.1.1 +short performance.umaxica.dev | head -1)
curl -s -o /dev/null --resolve "performance.umaxica.dev:443:$ip" \
  -w '%{http_code} %header{x-request-id} %header{www-authenticate} %header{location}' \
  "https://performance.umaxica.dev<path>"
```

A response carrying `x-request-id` was produced by Rails. The query string of each Access login URL
was redacted before recording.

## Result

`dig @1.1.1.1` answered `104.21.31.129` and `172.67.176.136`.

| Request                                             | Status | `x-request-id` | Outcome                         |
| --------------------------------------------------- | ------ | -------------- | ------------------------------- |
| `GET /`                                             | 302    | absent         | Redirect to the Access login    |
| `GET /requests`                                     | 302    | absent         | Redirect to the Access login    |
| `GET /crashes`                                      | 302    | absent         | Redirect to the Access login    |
| `GET /rails/info/routes`                            | 302    | absent         | Redirect to the Access login    |
| `GET /probe1791389199` (nonce)                      | 302    | absent         | Redirect to the Access login    |
| `GET /.env`                                         | 302    | absent         | Redirect to the Access login    |
| `POST /`                                            | 302    | absent         | Redirect                        |
| `GET /forged<epoch>` with a forged Access assertion | 302    | absent         | Redirect                        |
| `GET http://performance.umaxica.dev/`               | 301    | absent         | Redirect to `https`             |

The six `GET` requests over `https` without an assertion returned
`WWW-Authenticate: Cloudflare-Access` and a `Location` under
`umaxica.cloudflareaccess.com/cdn-cgi/access/login/performance.umaxica.dev`.

The forged request sent `CF_Authorization` and `Cf-Access-Jwt-Assertion` with an invalid token.

Origin log: `log/development.log` and `log/development.access.jsonl` gained no line containing the
nonce, `forged`, or `performance.umaxica.dev` during the probes. No unauthenticated request reached
Rails.

Origin, called directly inside the Dev Container: `GET /` with `Host: performance.umaxica.dev` on
`127.0.0.1:3000` answered `401` with `WWW-Authenticate: Basic realm="Rails Performance"`.

## Not verified

- A request that passes Access. No Access identity was available, so the tunnel route to the origin
  is unconfirmed: a wrong origin in the published hostname would look the same from outside.
- The Access policy: who it admits, and whether it matches the other dashboard hostnames.
- Whether the published route enables Access validation at the connector.
- Paths other than those listed, and bypass paths configured in the Access application.
