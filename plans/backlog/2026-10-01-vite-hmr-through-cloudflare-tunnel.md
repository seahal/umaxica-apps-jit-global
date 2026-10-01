# Vite HMR Through Cloudflare Tunnel

Date: 2026-10-01

Status: Proposal. Not accepted, not implemented. Kept for a later decision.

Related:

- `docs/architecture/cloudflare-request-paths.md` — development ingress (Access → Tunnel → `core`)
- `docs/operations/development-host-port-exposure.md` — loopback-only host port publication
- `vite.config.ts`, `config/vite.json` — dev server on port 3036, public output dir `vite-dev`

## 1. Problem

Vite hot module replacement (HMR) does not work when development is opened through a public
hostname published by Cloudflare Tunnel (for example `https://auth.umaxica.app`).

Observed in `log/development.log` (`security.csp_violation.reported`): the HMR client loaded from
`https://<host>/vite-dev/@vite/client` tries to open `wss://localhost:3036/vite-dev/`. For a browser
outside the devcontainer, `localhost` is the browser's own machine, so the socket never connects.

## 2. Why publishing a port does not help

- Cloudflare Tunnel exposes a public hostname on 443 and routes by ingress rule. It cannot expose
  `<host>:3036` as an additional public port.
- `127.0.0.1:3036:3036` in `.devcontainer/compose.yaml` is host loopback access only and is
  unrelated to the tunnel path.

## 3. Why a routing split is required

All tunnel traffic currently goes to Rails (Puma). `vite_ruby` forwards `/vite-dev/` to the Vite dev
server through `rack-proxy`, which relays plain HTTP but not the WebSocket `Upgrade`. Only Vite can
terminate the HMR socket, so something in front of Rails must send that socket to Vite.

## 4. Proposed change

### 4.1 Vite client target

Make the HMR client connect back to the page's own host on 443 over `wss`, gated by an environment
variable so direct `localhost` development keeps the current behavior:

```ts
server: {
  hmr: process.env.VITE_HMR_CLIENT_PORT
    ? { protocol: "wss", clientPort: Number(process.env.VITE_HMR_CLIENT_PORT) }
    : undefined,
},
```

Without `hmr.host`, the client uses the page hostname. Add `VITE_HMR_CLIENT_PORT` to
`.env.devcontainer.example` with a comment explaining it applies only to tunnel access.

### 4.2 Tunnel ingress path rule

Add one rule per public hostname pattern, ordered before the rule that sends traffic to Rails:

```yaml
- hostname: "*.umaxica.app"   # likewise for .com and .org
  path: ^/vite-dev/
  service: http://core:3036
```

`cloudflared` passes WebSocket upgrades through unchanged. The tunnel configuration lives outside
this repository; changing it is an external write and needs its owner's approval.

### 4.3 CSP

No change expected. A same-origin `wss://<host>` connection is covered by `connect-src 'self'`. The
existing `ws(s)://<host>:3036` entries could be removed once the path rule works; verify in a browser
before removing them.

## 5. Alternatives considered

| Option                                                   | Cost                                                                                                                   |
| -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Separate Vite hostname (e.g. `vite.umaxica.app` → 3036)  | Still one more tunnel rule, plus a cross-origin socket: CSP and `allowedHosts` additions and extra DNS/certificates   |
| Put Vite in front and proxy to Rails via `server.proxy`  | Every request passes through Node; outside `vite_ruby`'s model; Cookie, `Host`, and forwarded-header handling must be reworked, risking auth boundaries |
| Relay WebSockets inside Rails/Puma                       | Custom proxy code maintained only for development                                                                      |
| Accept no HMR through the tunnel                         | No routing change; manual reload after each edit                                                                       |

The path rule is the smallest change: one ingress rule per hostname pattern, no Rails or CSP change.

## 6. Security notes

- The path rule exposes the Vite dev server directly to tunnel clients, bypassing Rails middleware
  (host authorization, request size limit). Keep it behind Cloudflare Access, and keep
  `server.allowedHosts` and the default `server.fs.strict`.
- Bot scans on 2026-10-01 already probed `@fs` paths (CVE-2025-30208 style). Locally,
  `/vite-dev/@fs/...` returned 403 on Vite 8.3.1. Recheck after enabling the rule, and track Vite
  security releases while the dev server is reachable from the tunnel.
- Production is unaffected: it serves prebuilt assets and runs no dev server or proxy.

## 7. Open questions

- Where the tunnel ingress configuration is managed (dashboard vs. local config file).
- Whether hostnames other than `*.umaxica.{app,com,org}` (for example `www.umaxica.dev`) need HMR.
