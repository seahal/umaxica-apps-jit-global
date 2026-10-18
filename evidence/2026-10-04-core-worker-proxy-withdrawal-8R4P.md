# Core browser proxy withdrawal

Executed on 2026-10-04, approximately 00:12–00:20 UTC. Rails feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` had concurrent uncommitted changes.
Edge main HEAD `185dd076404011ed391b2b550091be3fd7939ba0` at
`/home/global/umaxica-apps-edge` was dirty with the previous credential-header
change and this slice. No Rails implementation or database changed here.

## Reproduction and change

New Worker-entrypoint tests supplied a synthetic VPC binding and observed its
calls. GET, HEAD, POST and OPTIONS all invoked the old Rails transport: four
actual failures in the app selection. Its 30 unselected tests were reported as
skipped by the name filter, not modified or permanently disabled. The initial
direct Worker Hurl request expected the approved blocked response but received
the old transport's 503. Its other four files passed.

Each Core entrypoint now uses the existing bodyless no-store blocked response
for a classified Rails path after existing rate-limit checks. No binding,
global fetch or application handler is called. Application credential stripping
and outbound Set-Cookie stripping remain. Replaced Worker tests whose explicit
forwarding expectations belong to the superseded contract; application, limiter
and blocked-namespace tests remain. New binding tests cover all four methods.

Added three Hurl files covering seven misplaced API/protocol requests each.
ADR 016 records local withdrawal, deferred routing cutover and incomplete Core
migration; ADR 007 points forward while retaining history. Updated Core agent
instructions and API test scope descriptions. No external routing changed.

## Actual commands and results

Commands used the existing pnpm 12.0.0 binary on task-local PATH, from Edge:

- `pnpm --dir app/core run test test/worker.test.ts`: Green, 24 tests passed.
- `pnpm --dir <app|com|org>/core run test:api`: final PASS, five files and
  29 requests per surface, 87 requests total.
- `pnpm run check`: static phases completed, but test fan-out failed with
  Vitest child-process `write EPIPE` in com/docs. This command is **FAIL**,
  not a clean full-check result; the underlying resource cause was not proven.
- `pnpm -r --workspace-concurrency=1 run test --maxWorkers=2`: PASS across
  all twenty units, without changing coverage thresholds or test selection.
  Each Core had 315 passing tests. This supersedes the interrupted test phase.
- Root script's tracked-file environment plus
  `pnpm exec vitest run --dir test --maxWorkers=2`: 12 files passed,
  437 tests passed, one existing container-engine-dependent skip. No new skip.
- `pnpm --dir <app|com|org>/core run build`: PASS for all three production
  artifacts, with no Cloudflare/AWS deployment.
- `pnpm --dir <surface>/core exec wrangler dev --config
  dist/server/wrangler.json --port <5406|5106|5306> --local`: local built
  Worker servers started. Hurl ran each existing misrouting file plus a
  temporary OPTIONS case: two files/eight requests per surface, all passed.
  The OPTIONS case requested `/api/v0/session` with synthetic Cookie and
  Authorization and asserted 404, empty body, no-store, nosniff and no
  Location/Set-Cookie. Owned launchers were identity-checked, terminated and
  their session completion observed. No health/upstream request was made.
- `pnpm --dir <app|com|org>/core run check:size`: **FAIL** for all three.
  Existing limit: 129 kB gzipped. Reported app: 184.99 kB; com/org: 185 kB.
  The limit was not raised. No previous-HEAD build comparison was performed,
  so this is not attributed to either an existing defect or this change.
- Final affected-document Oxfmt check, CSpell (four files, zero issues) and
  Edge `git diff --check`: PASS.

## Local runner distinction

Vite intercepted OPTIONS with 204 before the Worker, both without Origin and
with a foreign Origin. Those three-surface HTTP runs failed the proposed 404
assertion. Fixed-version local Vite 8.2.2 source contains the preflight middleware.
No CORS policy was weakened to make the test pass. OPTIONS was removed from the
Vite-driven Hurl matrix because that runner cannot reach this boundary; its
Worker-level expectation remains and the production-build workerd requests above
subsequently proved the 404. The API READMEs retain this distinction.

## Remaining limits

The historical dispatch utility and its direct tests still exist; the live
browser entrypoint no longer calls it. The health route still performs a
server-side Rails probe and needs its own contract reconciliation. Consequently
the entire no-Workers-to-Rails requirement is not yet complete.

No real-browser authentication, Rails/Edge authenticated integration, refresh
continuation or external path-routing/cache test ran. Production routing must
be confirmed before deploying the withdrawal; dynamic-cache, CloudFront and
credential-forwarding deployment gates remain independent. The new Hurl files
target the Worker directly, not a correctly routed shared production origin.
No Secret shape approval was inferred, no credential protocol changed, and no
shared database, key, binding, push or deployment was modified.
