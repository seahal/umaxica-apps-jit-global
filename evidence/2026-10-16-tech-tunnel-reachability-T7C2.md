# tech.umaxica.org reachability through Cloudflare

- Commit: `8e302ed42b45e45dcc73225b52fe08357432c9db` on `feature`, clean worktree. No repository file
  was changed for this result. The routes and Access applications live in the Cloudflare dashboard,
  which this session neither read nor changed. The user reported the tunnel route table and the
  apex edit described below.
- Actor: Claude Opus 5.5 (claude-opus-5-5), working from inside the development `core` container,
  on 2026-10-16 (UTC).
- Result: `https://tech.umaxica.org/` reaches development Rails through the Cloudflare edge and the
  remotely managed Tunnel, and Rails serves `Tech::Org::RootsController#index`. The user reported
  opening the page in a browser through Cloudflare Access. This session did not verify that Access
  blocks unauthenticated requests; see "Open" below.

## Observations

- The Tunnel route for `tech.umaxica.org`, as reported by the user, is a published application
  routed to `http://tech.org.localhost:3000` with default origin settings. The `core` alias for that
  name is at `.devcontainer/compose.yaml:208`.
- `cloudflared` readiness: `curl http://cloudflare-tunnel:2000/ready` returned
  `{"status":200,"readyConnections":4,...}`.
- The Rails origin returned 200 for `curl http://tech.org.localhost:3000/?ri=jp` and for the same
  request with host `tech.umaxica.org:3000`, so Host Authorization admits the public name.
- Public DNS: at first `dig tech.umaxica.org @1.1.1.1` returned NOERROR with no answer, and the
  Cloudflare edge returned 530. A later lookup resolved to `104.21.90.11`. The record had not yet
  been published when the first lookup ran.
- Edge path: `curl -I --resolve tech.umaxica.org:443:104.21.90.11 https://tech.umaxica.org/?ri=jp`
  returned `HTTP/2 200` with `server: cloudflare`, `cf-ray: a4b5d93e8ed90b25-NRT` and a Rails
  `server-timing` header. `--resolve` is needed because the container's `/etc/hosts` maps the
  public names to `core` itself.
- `log/development.access.jsonl` (last modified 08:57 UTC) recorded the probe's `HEAD /` and three
  later `GET /` requests to `Tech::Org::RootsController#index`: one 302 to
  `https://tech.umaxica.org/`, then two 200s. `log/development.log` also recorded
  `Redirected to https://tech.umaxica.org/?ri=jp`. The access log has no per-line timestamps.
  Attributing the GETs to the user's browser is an inference from timing.
- The apex routes (`umaxica.app`, `.com` and `.org` to `http://xper.*.localhost:3000`) returned 502
  because no `xper` origin or alias exists. The user reported removing these stale routes. Afterward
  `dig @1.1.1.1` returned only the SOA for each apex, with no A or CNAME record.

## Open

- The unauthenticated probe above, sent with no Access cookie or service token, received 200
  directly, with no redirect to an Access login. `edit`, `www` and `auth.umaxica.org` behaved the
  same way. `docs/architecture/cloudflare-request-paths.md` expects development hostnames to sit
  behind Access, but this result shows Access is not enforced for these names. Check the Access
  application and policy coverage in the dashboard. `pghero`, `blazer`, `flipper` and
  `mission.umaxica.dev` were not probed.
