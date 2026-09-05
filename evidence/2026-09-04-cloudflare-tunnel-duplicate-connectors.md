# Cloudflare Tunnel unreachable: duplicate connectors on one token

Reported symptom: Rails server not reachable through the Cloudflare Tunnel.

## Observed

Three cloudflared containers were running, all with an identical `TUNNEL_TOKEN`
(md5 of the env line `eb48b24a3854ae2e3777d146a11c4559`), i.e. three connectors
registered on the same tunnel. Origin reachability probed with a throwaway
`curlimages/curl` container joined to each connector's network:

| connector | network | `http://www.umaxica.app:3000/` |
| --- | --- | --- |
| `umaxicaappsglobaldc_cloudflare-tunnel_1` | `umaxicaappsglobaldc_frontend` | 302 |
| `umaxica-apps-global-dc_cloudflare-tunnel_1` | `umaxica-apps-global-dc_frontend` (connector was the only member) | 000 |
| `umaxicaappsedge_cloudflare-tunnel_1` | `umaxicaappsedge_default` (apps-edge stack) | 000 |

The edge load-balances a tunnel's requests across all of its connectors, so
roughly two thirds of requests reached a connector with no route to `core`.

Rails itself was healthy: `ss -ltnp` inside `global-devcontainer-core` showed
`0.0.0.0:3000` (LISTEN, ruby), and `curl -H 'Host: www.umaxica.app'
http://127.0.0.1:3000/` returned 302 in-container. cloudflared's own
connectivity pre-checks all passed on every connector, so the connector logs
gave no indication of the fault.

`umaxica-apps-global-dc_*` was a leftover from the pre-rename project namespace.

## Actions

- `podman rm -f umaxica-apps-global-dc_cloudflare-tunnel_1`
- `podman network rm umaxica-apps-global-dc_frontend`
- `podman stop umaxicaappsedge_cloudflare-tunnel_1`

## After

One connector remains. `http://cloudflare-tunnel:2000/ready` on
`umaxicaappsglobaldc_frontend` returns
`{"status":200,"readyConnections":4,"connectorId":"3b01dcc7-2b42-4f47-a5a7-88389133bff7"}`.

End-to-end browser access through the tunnel was not verified in this session.

## Follow-up not done

`CLOUDFLARED_TOKEN` is shared between this repository and apps-edge. One tunnel
serves one origin network, so running both stacks at once reintroduces the
fault. A separate tunnel and token for apps-edge is the durable fix.
