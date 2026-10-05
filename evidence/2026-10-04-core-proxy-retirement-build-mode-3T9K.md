# Core proxy retirement and production build mode

Executed on 2026-10-04, approximately 00:21–00:35 UTC. Rails feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` and Edge main HEAD
`185dd076404011ed391b2b550091be3fd7939ba0` had uncommitted changes. Edge is
`/home/global/umaxica-apps-edge`. This slice changed only Edge implementation,
documentation and tests, plus this Rails evidence record.

## Browser proxy retirement

The prior slice stopped calling the browser proxy, but its exported function
and dedicated logger remained. Added a public-module boundary assertion for
each Core: ownership-only exports, with no transport interface. Red: three
failures because dispatchToRails was still exported. The 40 other cases were
unselected by the temporary name filter, not disabled.

Removed the three browser transport implementations, dispatch-only logger files
and their dedicated tests. Kept pure ownership classification and the existing
blocked response; updated consumers and root contract expectations for the
approved target. Root contract selection then passed 36 tests. No alias,
compatibility transport or new fallback was introduced. Core health still uses
its separate Rails probe; Info and other surfaces were not changed.

Updated ADR 009's partial supersession, ADR 010's still-applicable rate limiting,
ADR 016's implementation limits and the retired logging guidance. Added a
pending Core health shape proposal under Edge plans. An asynchronous approval
request was registered; no answer or approval was inferred from registration.

## Measured production build defect

Ambient NODE_ENV was development. Normal Core builds contained development React
and jsx-dev-runtime. Fixed local Vite 8.2.2 resolveConfig preserves an already-set
NODE_ENV and derives isProduction from it. The official
[Vite environment/mode contract](https://vite.dev/guide/env-and-mode.html#node-env-and-modes)
also distinguishes production mode from NODE_ENV. An unchanged-source app probe
with NODE_ENV=production reduced the configured size measurement from the prior
184.99 kB to 117.77 kB, passing the unchanged 129 kB budget.

Each Core's ordinary build script now sets NODE_ENV=production. No caller must
export a new variable, no library was upgraded and no budget/configuration
threshold was lowered. Existing serving scripts remain unchanged. Updated the
build measurement documentation; did not add an environment-construction test.

## Actual verification

- `pnpm --config.workspace-concurrency=1 run check`: final **PASS**, exit 0,
  all static phases and all twenty unit suites. Each Core: 224 tests passed.
  Root: 12 files, 433 passed and one existing conditional skip. No new skip.
  An earlier retirement check passed; subsequent checks failed at formatting
  of the new proposal, which was formatted before the final successful check.
- `pnpm --dir <app|com|org>/core run test:cov --maxWorkers=2`: PASS for each,
  configured statements/branches/functions/lines all 100%. Existing coverage
  exclusions and thresholds were unchanged.
- `pnpm --dir <app|com|org>/core run build`: PASS for all three with the normal
  fixed script and inherited development shell environment.
- Corresponding `run check:size`: PASS, app 117.77 kB, com 117.78 kB,
  org 117.77 kB gzipped, against the existing 129 kB limit.
- Built Worker Hurl checks: seven repository misrouting cases plus the temporary
  OPTIONS case, eight requests per surface, all 24 passed. The repository cases
  additionally assert noindex/nofollow. Requests were delivered directly to
  local built Workers, not to a deployment or private Rails origin.
- Final Edge `git diff --check`: PASS. Code/test searches found no remaining
  dispatchToRails or rails-dispatch-log reference in Core source/root tests.

Local runtime attempts initially collided on the default inspector port. A
subsequent app attempt aborted and a shell reported fork exhaustion while
static checks and runtime processes overlapped. These are recorded failed setup
attempts, not product Red evidence. Used distinct task-owned local inspector
ports and completed runtime requests. Killing a pnpm launcher alone left an org
Wrangler child alive; verified its identity and used SIGINT on the actual CLI.
All final owned CLI sessions were stopped, and HTTP ports 5406/5106/5306 were
observed with no listeners. No external health/proxy request was made.

## Limits

No real-browser, Rails authenticated integration, refresh continuation, external
cache/routing or deployment test ran. No Rails/Secret code, database, key,
production setting, push or deployment changed here. The build fix is limited
to three Core units; production build results for other seventeen units are not
claimed. Production routing cutover remains required before deploying browser
proxy withdrawal. Core health's separately gated response change and browser
authentication/stale-response work remain unfinished.
