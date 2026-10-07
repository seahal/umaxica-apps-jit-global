# External Probe of the `.dev` Hostnames for Cloudflare Access Coverage

Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`. The worktree had many unrelated uncommitted
changes; none of them affects this result, which measures Cloudflare-account configuration.

Plan: `plans/backlog/2026-10-08-dev-dashboard-hosts-cloudflare-access-gate.md`.

## Method

The repository owner ran one unauthenticated `GET /` per hostname from the development host shell,
outside the Dev Container, at 2026-10-07T15:34:40Z:

```bash
curl -s -o /dev/null -m 15 \
  -w 'status=%{http_code} server=%header{server} rails=%header{x-request-id} auth=%header{www-authenticate} loc=%{redirect_url}\n' \
  "https://<name>.umaxica.dev/"
```

A response carrying `x-request-id` was produced by Rails. The query string of each Access login URL
holds a signed assertion and was redacted before recording.

## Result

| Hostname                  | Status | `x-request-id` | Outcome                                                        |
| ------------------------- | ------ | -------------- | -------------------------------------------------------------- |
| `mission.umaxica.dev`     | 302    | absent         | Redirect to `umaxica.cloudflareaccess.com`. Access-gated.      |
| `flipper.umaxica.dev`     | 302    | absent         | Redirect to `umaxica.cloudflareaccess.com`. Access-gated.      |
| `blazer.umaxica.dev`      | 302    | absent         | Redirect to `umaxica.cloudflareaccess.com`. Access-gated.      |
| `coverband.umaxica.dev`   | 302    | absent         | Redirect to `umaxica.cloudflareaccess.com`. Access-gated.      |
| `swagger.umaxica.dev`     | 302    | absent         | Redirect to `umaxica.cloudflareaccess.com`. Access-gated.      |
| `pghero.umaxica.dev`      | 500    | present        | **Reached Rails with no Access application in front.**         |
| `performance.umaxica.dev` | 000    | absent         | No HTTP response. The cause was not determined.                |
| `www.umaxica.dev`         | 500    | present        | Reached Rails. Publication without Access is the decision.     |
| `jp.umaxica.dev`          | 500    | present        | Reached Rails. Publication without Access is the decision.     |

The five gated hostnames also returned `WWW-Authenticate: Cloudflare-Access`.

## Not verified

- Why `performance.umaxica.dev` returned no response: a missing DNS record and a timeout both print
  `000` with this command.
- The cause of the three `500` responses. `log/development.log` held
  `ActiveRecord::PendingMigrationError` entries at the time, but the three request identifiers were
  not matched to them.
- That an unauthenticated request to a gated hostname is absent from the origin log. The nonce probe
  was not run.
- Whether the published routes enable Access validation at the connector.
