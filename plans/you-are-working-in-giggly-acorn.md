# Workers VPC Origin-Readiness Audit — Info/Help/News/Docs × app/com/org (twelve origins)

## Context

Twelve Next.js apps on Cloudflare Workers (separate repo) will reach this Rails app via Workers VPC
Service → existing Cloudflare Tunnel → Podman `frontend` network → Rails. The task is to prove, per
host, that each of the twelve origins (`info|help|news|docs`.`app|com|org`.localhost) is reachable
and correctly host-routed from the cloudflared private-network position, and to produce the exact
operator-side VPC Service configuration. The five browser-facing surfaces (base/auth/palm/core/side)
were finished this morning and are out of scope except for regression preservation. Prefer zero code
changes; edit only where evidence shows a gap.

## Established facts (Phase 1 pre-verified by read-only exploration)

- Rails compose service: `core`, `bin/dev`, `PORT=3000`, `BINDING=0.0.0.0`; networks include
  `frontend`; no host ports in base `compose.yaml` (only devcontainer override publishes 3000/3036).
- `cloudflare-tunnel`: `cloudflare/cloudflared:2025.7.0`, `command: tunnel --protocol quic run`,
  token via `TUNNEL_TOKEN: ${CLOUDFLARED_TOKEN}` env (not argv), attached to `frontend` only.
- All twelve aliases already exist on `core`'s `frontend` network (`compose.yaml` lines ~189–207).
- Existing probe: `bin/tunnel-origin-check` — ephemeral pinned `curlimages/curl:8.16.0@sha256:…`
  container on the compose-labeled `frontend` network, probes `http://<host>:3000/health` for all 27
  origin hosts including the twelve. This IS the Phase 4 mechanism; reuse it.
- Existing contract doc: `docs/operations/cloudflare-private-origin.md` (transport invariant,
  Workers VPC prerequisites: cloudflared ≥2025.7.0, QUIC, UDP 7844, TUNNEL_TOKEN).
- Rails routing: each of the twelve hosts has a literal host constraint in
  `config/routes/{info,help,news,docs}.rb` → `<surface>/<tier>/*` controllers, each with
  `roots#index`, `/health` (+liveness/readiness/startup), `/csp-violation-report`,
  `/api/v0/entries`. Route-contract tests exist per surface in
  `test/integration/routes/{info,help,news,docs}_route_contract_test.rb` covering all twelve
  localhost hosts via `recognize_path`.
- Host Authorization (dev): `config/environments/development.rb:123-224`. The
  `localhost_tunnel_hosts` literals carry `:3000` (Rails matches `request.host` WITHOUT port, so
  these literals only matter as strings that never see a port — must verify effective behavior);
  bare hosts for info/help come from `boot_config_hosts`, and for docs/news from `env_hosts`
  expansion of `PRIVATE_DOCS_*`/`PRIVATE_NEWS_*` env vars, which compose.yaml sets to the
  `.localhost` values. Test env has host authorization off, so Phase 6 must be an effective probe
  against the running dev container, not a Minitest.
- No `/up`; health endpoint is `/health` per surface. Dev has NO host_authorization exclude, so in
  dev `/health` responses DO pass host authorization — but keep transport vs host-auth gates
  reported separately anyway, and use `/` (roots#index) as the non-excluded routing/host-auth path.

## Official documentation findings (already fetched, cite in report)

- developers.cloudflare.com/workers-vpc/configuration/vpc-services/ — the configured VPC Service
  target controls routing: "The host provided in the fetch() operation is not used to route
  requests"; "The port provided in the fetch() operation is ignored." Fetch URL hostname populates
  the HTTP Host header (and SNI). Hostname targets need `resolver_network` (tunnel ID); cloudflared
  resolves via the default system resolver of its network position (= Podman aardvark-dns inside the
  container ⇒ compose aliases resolve).
- developers.cloudflare.com/workers-vpc/configuration/tunnel/ — cloudflared ≥ 2025.7.0; QUIC
  required (`auto` or `quic`); outbound UDP 7844 must be allowed; tunnel ingress/published-hostname
  rules NOT required for Workers VPC (routing handled by the VPC Service). HTTP/2-only transport is
  therefore insufficient — QUIC is mandated.
- Consequence: ONE VPC Service targeting the Rails service (target hostname `core`, the compose
  service DNS name — narrowest stable Podman-DNS name, no container IP), `http_port: 3000`, with the
  twelve `fetch()` URL hostnames selecting surfaces via Host routing. Twelve VPC Services are NOT
  required. (Optionally target `info.app.localhost` etc. would also resolve, but `core` is the
  single stable service name.)
- Re-verify these pages during execution (Phase 2 of the audit) and cite exact sections; also spot
  check docs.podman.io on network aliases/DNS (aardvark-dns resolves compose `aliases` on
  user-defined networks) if needed for the report.

## Execution steps

1. **Phase 1 report** — re-confirm current `compose.yaml` facts with `podman compose config`
   (aliases render, no published ports on base config, cloudflared image/command/token). Build the
   initial 12-row matrix with evidence-based statuses.
2. **Phase 3 — Podman DNS audit** — expected result: all twelve aliases already present ⇒ zero
   compose changes. Prove resolution from the shared network position (step 3's probe proves DNS +
   TCP + HTTP together; if finer DNS-only evidence is wanted, use the same pinned curl image's
   resolution failure/success per host).
3. **Phase 4 — private reachability** — start the compose stack if not running
   (`podman compose up -d core cloudflare-tunnel` + deps as needed), then run
   `bin/tunnel-origin-check` (already probes all twelve from the cloudflared `frontend` network via
   ephemeral pinned curl). Record exact PASS/FAIL per host. Matrix: Host | DNS | TCP/HTTP | /health.
4. **Phase 5 — routing proof** — run the existing focused contract tests:
   `bin/rails test test/integration/routes/info_route_contract_test.rb test/integration/routes/help_route_contract_test.rb test/integration/routes/news_route_contract_test.rb test/integration/routes/docs_route_contract_test.rb`
   These already assert all twelve localhost hosts → expected `<surface>/<tier>` controllers. Only
   add/tighten tests if a host case is actually missing (from exploration: all twelve are covered —
   expect zero test additions).
5. **Phase 6 — effective Host Authorization** — probe the RUNNING dev Rails through the same
   private-network position with explicit portless Host headers (matching what a Worker fetch
   sends): ephemeral pinned curl on the frontend network,
   `curl -H "Host: info.app.localhost" http://core:3000/` for each of the twelve → expect 200 (or
   surface-rendered response, not 403 Blocked hosts). Also probe an unrelated host (e.g.
   `Host: evil.example`) → expect blocked response. This is effective Rack behavior, not grep. Note
   in the report the `:3000`-suffixed allowlist literals are inert for matching and that bare-host
   coverage comes from boot_config/env_hosts; make NO Rails config change if all twelve pass. If any
   host fails, minimal fix: add the bare literal to `localhost_tunnel_hosts` (portless) in
   `config/environments/development.rb` with red→green probe evidence.
6. **Phase 7 — cloudflared readiness** — already satisfied by current config (2025.7.0 ≥ minimum,
   `--protocol quic`, token via env not argv, shared `frontend` network). Expected: zero changes.
   UDP 7844 egress: report BLOCKED EXTERNALLY (repo cannot prove host firewall). Validate with
   `podman compose config`. Regression evidence for the five morning surfaces:
   `bin/tunnel-origin-check` PASS rows for base/auth/core/side/palm hosts (already in the script) —
   no compose diff ⇒ no regression risk.
7. **Phase 8 / docs** — if `docs/operations/cloudflare-private-origin.md` lacks the exact VPC
   Service operator contract, add a small section (in Japanese per user preference for docs? — NOTE:
   repository language policy requires English for repo files; follow
   `docs/reference/repository-language-policy.md` → English in-repo, Japanese for the chat report)
   documenting:
   ```
   VPC Service type: HTTP
   Tunnel: <existing tunnel UUID — operator-side, not stored in repo>
   Target hostname: core   (Podman compose service DNS name on the frontend network)
   HTTP port: 3000
   ```
   and the twelve Worker fetch Host values `http://{info|help|news|docs}.{app|com|org}.localhost/…`.
8. **Final report** — emit the 11-section format required by the task (Current Repository Reality,
   Official Documentation Findings, Twelve-Surface Matrix, Gaps, Changes, Red-to-Green, Gates 1–8,
   VPC Service config, Worker contract, Verification Results, Remaining Risks). Report every host
   individually; no wildcard claims. Chat report in Japanese per stored user preference.

## Expected change scope

- Rails application code changes: likely **zero**.
- compose.yaml changes: likely **zero** (all aliases present).
- Possible small doc addition to `docs/operations/cloudflare-private-origin.md` (VPC Service
  operator contract) — only if not already documented.
- Possible narrow dev-host allowlist fix ONLY if the Phase 6 effective probe fails for a host.

## Verification

- `podman compose config` (validates compose).
- `bin/tunnel-origin-check` (twelve-host private HTTP, plus five-surface regression rows).
- Ephemeral curl Host-header probes for effective Host Authorization (twelve accepted + one
  rejected).
- `bin/rails test test/integration/routes/{info,help,news,docs}_route_contract_test.rb` (twelve-host
  routing contracts).
- Broader suite only if Rails app code/config actually changes.

## Production Host Authorization Follow-up

The earlier twelve-host `200` probe exercised the effective development configuration. It did not
prove the production allowlist. A production-configured middleware probe on the non-excluded `/`
path found that `info.*` and `help.*` were accepted, while `news.*` and `docs.*` were rejected.
Production now explicitly allows only the six required `news.*` and `docs.*` localhost hosts; no
wildcard or compatibility alias was added.

### Corrected gate wording

- Gate 3 — PASS: the production-configured Host Authorization probe accepts all twelve requested
  Worker Host values on `/` (not `/health`); the unknown-host control remains rejected.
- Gate 5 — compose alias contract: PASS. Live Podman DNS resolution: UNVERIFIED; static compose
  aliases are not runtime DNS evidence.
- Gate 7 — NOT RE-VERIFIED; no shared configuration changes were made in this task.

### Red-to-green evidence

- RED: before the production allowlist change, the production middleware contract rejected all six
  `news.*`/`docs.*` values on `/`.
- GREEN: after the change, the same production-configured middleware contract accepts all twelve
  values with HTTP `200` and rejects `evil.example.com` with HTTP `403`.

## Forbidden (from task)

No Worker/Wrangler/Next.js code, no new VPC configs in repo, no public tunnel hostnames for the
twelve, no host-port publishing, no host-authorization weakening (`hosts.clear`, `*.localhost`
wildcards), no hard-coded IPs, no tokens committed, no Access rework.
