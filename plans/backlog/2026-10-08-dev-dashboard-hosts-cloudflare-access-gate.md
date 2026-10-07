# Cloudflare Access Gate for the `.dev` Dashboard Hosts

Date: 2026-10-08

Status: Partly contained. A probe at 2026-10-07T15:34Z measured five dashboard hostnames behind
Access and `pghero.umaxica.dev` still reaching Rails without it. The steps in section 3 are
proposed, not accepted, and not implemented.

Related:

- `adr/diagnostic-surfaces-performance-coverband-swagger.md` — the dashboard pattern and its Basic
  Auth control
- `docs/architecture/cloudflare-request-paths.md` — "Development Is Tunnel-Exposed Behind Access"
- `docs/operations/cloudflare-private-origin.md` — "Browser Traffic Through Access" and "External
  Checks"
- `notes/implementation/2026-08-10-development-tunnel-access-verification.md` — the only measured
  Access verification
- `evidence/2026-10-02-dev-rails-info-tunnel-exposure-K7Q2.md`,
  `evidence/2026-10-05-dev-detailed-errors-tunnel-exposure-Q4T8.md` — earlier tunnel exposure
  findings
- `evidence/2026-10-08-dev-hostname-access-probe-H3W7.md` — the probe that measured the state below

## 1. Record

On 2026-10-08 the repository owner reported that the operator dashboards on the `.dev` domain were
published through Cloudflare Tunnel without a Cloudflare Access application in front of them. They
were reachable from the public internet, and the origin's HTTP Basic Auth was the only control.

The affected hostnames, as aliased to `core` in `.devcontainer/compose.yaml`:

| Hostname                  | Tool                 | What an authenticated visitor can do               |
| ------------------------- | -------------------- | -------------------------------------------------- |
| `mission.umaxica.dev`     | Mission Control Jobs | Read, retry, and discard jobs in the Solid Queue   |
| `flipper.umaxica.dev`     | Flipper UI           | Change feature flags                               |
| `blazer.umaxica.dev`      | Blazer               | Run SQL against the development databases          |
| `pghero.umaxica.dev`      | PgHero               | Read query statistics and act on running queries   |
| `performance.umaxica.dev` | rails_performance    | Read request paths, traces, and exception classes  |
| `coverband.umaxica.dev`   | Coverband            | Read this repository's source, line by line        |
| `swagger.umaxica.dev`     | Swagger UI           | Read the inventory of every internal JSON endpoint |

### Containment and decision

Later on 2026-10-08 the owner reported two things:

- Every `.dev` hostname except `www.umaxica.dev` and `jp.umaxica.dev` was made unreachable to an
  unauthenticated visitor. The dashboards remain reachable on the development host at
  `*.core.dev.localhost`.
- `www.umaxica.dev` and `jp.umaxica.dev` must be publicly reachable and stay published. That
  exposure is deliberate.

The owner then probed all nine hostnames from outside the Dev Container
(`evidence/2026-10-08-dev-hostname-access-probe-H3W7.md`):

- `mission`, `flipper`, `blazer`, `coverband`, and `swagger` answer with a redirect to the Access
  login. They are gated by Access, not removed from the tunnel.
- **`pghero.umaxica.dev` still reaches Rails with no Access application in front.**
- `performance.umaxica.dev` returned no HTTP response; the cause is undetermined.
- `www` and `jp` reach Rails, as decided.

The original exposure itself was not measured; it rests on the owner's report.

### How the gap went unnoticed

The repository states that Access fronts the dashboard hosts, as a fact, in at least these places:
`config/routes/{mission,flipper,coverband}.rb`, `config/initializers/{blazer,pghero,rails_performance}.rb`,
`lib/diagnostic_surface_credentials.rb`, and `adr/diagnostic-surfaces-performance-coverband-swagger.md`.
None of them rests on a measurement:

- The 2026-08-10 verification covered ten `umaxica.{app,com,org}` hostnames and no `.dev` hostname.
- The ADR that added three of the dashboards says Tunnel, DNS, and Access "were not touched".
- `docs/operations/cloudflare-private-origin.md` already requires the Access application to exist
  before its hostname is published, and lists that as an external check that is "blocked until
  verified". The check was never run for `.dev`, and nothing forces it to run.

The two earlier evidence records show the same pattern outside `.dev`: scanner traffic reached the
development origin through the tunnel on `edit.umaxica.org` and on the apex
`umaxica.{com,app,org}` hosts. Access coverage is therefore unconfirmed for every published
hostname that the 2026-08-10 run did not measure.

### Why Basic Auth alone was not enough

Basic Auth held as designed: it fails closed, and it is the reason the report is "exposed", not
"open". It is still a weak sole perimeter for these tools:

- One shared static credential per tool, with no second factor and no per-person identity.
- The mounted engines run outside this application's `RateLimit` and `FqdnAvailabilityGate`
  (`config/routes/mission.rb`), so nothing in Rails slows online password guessing.
- Every request, including an unauthenticated one, reaches Puma, Rack, and the engine's middleware
  stack. A defect in any of them is reachable before the credential check.

## 2. Resulting state

- **Dashboards:** five are behind Access, with Basic Auth at the origin unchanged behind it.
  `pghero` is not gated yet, and `performance` is unconfirmed.
- **`www.umaxica.dev` and `jp.umaxica.dev`:** published without Access, by decision. Rails
  authentication, authorization, and rate limiting are the only controls on these two hostnames.
  `config.consider_all_requests_local = false` in `config/environments/development.rb` is
  load-bearing for them: reverting it serves the route table and detailed exception pages to the
  internet, as the 2026-10-05 evidence measured.

Each published dashboard route should also enable Access validation at the connector
(`originRequest.access` with `required`, `teamName`, `audTag`), so `cloudflared` refuses a request
without a valid Access token even if the edge application is later deleted. Whether the five gated
routes have this is not measured. A wildcard `*.umaxica.dev` Access application would make "gated" the default for any new
`.dev` hostname, but it would also cover `www` and `jp`, which then each need an explicit exception.

## 3. Remaining steps

1. **Gate `pghero.umaxica.dev`.** Add its Access application, or remove its public hostname. Then
   settle `performance.umaxica.dev`: find out whether it has a DNS record and a tunnel route, and
   gate or remove it. Repeat the probe and record it in `evidence/`, with the nonce probe from the
   2026-08-10 note for one gated hostname to show the request is absent from the origin log.
2. **Rotate.** Replace all seven Basic Auth credential pairs. They were the sole control on a public
   listener for an unknown period, so treat them as possibly guessed or observed.
3. **Review the exposure window.** Search `log/development.access.jsonl` and `log/development.log`
   for requests to the seven hostnames that returned anything other than `401`, and compare the
   client addresses with the staff's own. Record what the logs can and cannot show, including how
   far back they reach.
4. **Correct the repository.**
   - Once step 1 is measured, the "Cloudflare Access fronts ..." comments and the ADR passage
     listed in section 1 describe a verified fact and can stay. Cite the evidence record from the
     ADR.
   - Record in `docs/architecture/cloudflare-request-paths.md` that `www.umaxica.dev` and
     `jp.umaxica.dev` are published without Access by decision. Its section "Development Is
     Tunnel-Exposed Behind Access" currently says otherwise for all development hostnames.
   - Add the `.dev` hostnames to "External Checks" in
     `docs/operations/cloudflare-private-origin.md`.
5. **Repeat the probe** whenever a hostname is published or an ingress rule changes, and
   record it in `evidence/`. Under `adr/no-test-suite-for-environment-construction.md` this is a
   run-and-record check, not a Minitest case.

## 4. Open questions

- Since when each dashboard hostname had been published.
- Why `www.umaxica.dev`, `jp.umaxica.dev`, and `pghero.umaxica.dev` answered `500` during the
  probe. `log/development.log` held `ActiveRecord::PendingMigrationError` entries at the time; the
  link is not confirmed.
- Whether `jp.umaxica.dev` is published with a path restriction like the one recorded for
  `jp.umaxica.{app,com,org}`, or with every path.
- Whether the apex `umaxica.{app,com,org}` hosts and `edit.umaxica.org` are meant to be
  Access-gated. The evidence records of 2026-10-02 and 2026-10-05 suggest they are not gated today.
