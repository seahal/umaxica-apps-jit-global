# Core Edge application credential boundary

Executed across 2026-10-03 23:49 UTC through 2026-10-04 00:02 UTC.
Rails checkout: feature HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, dirty
with concurrent changes. Edge checkout: newly obtained main at
`185dd076404011ed391b2b550091be3fd7939ba0`, initially clean, then dirty with
the three Core workers and their worker tests. Edge path is
`/home/global/umaxica-apps-edge`. No existing checkout was replaced.

## Available source and setup

No Edge checkout was found under /home/global. GitHub CLI was unauthenticated,
but public read access succeeded. `git ls-remote` identified main/HEAD and the
feature/develop refs; `git clone --depth 1` obtained the known public repository's
default branch. No worktree, branch switch, external edit, push or deployment ran.
Read root and all three Core AGENTS files, ADR 007, manifests and worker sources.

The environment had Node 24.20.0 but no pnpm or Corepack. The attempted official
GitHub standalone v12.0.0 URL returned 404. The repository-configured registry
provided pnpm 12.0.0 metadata. Downloaded its official package tarball, verified
the declared SHA512, and used its existing native downloader to obtain the
pinned CLI in `/tmp/umaxica-edge-pnpm-tool`. One invocation from the Rails
directory refused its different package-manager contract; rerunning from Edge
reported 12.0.0. No package-manager policy was disabled or version upgraded.

`pnpm install --frozen-lockfile` passed, including the existing supply-chain
policy verification. It installed 574 packages and local hooks; the tracked
lockfile and configuration remained unchanged. Checks below used a task-local
PATH containing that pnpm binary. No new application environment variable was
introduced. Setup is recorded here, not covered by a new environment test.

## Reproduced and fixed

The application branch stripped Cookie but passed Authorization into appHandler.
Added one internal-boundary test in each Core worker suite. Each failed on the
presence of Authorization, with its other 29 tests passing. The injected handler
observes a server-side Request, which an HTTP client cannot inspect; Vitest is
the repository-prescribed layer for that assertion. The test uses a synthetic
sentinel and verifies request-ID preservation. It does not mock authentication
success or the header-removal implementation.

Each Core worker now deletes Authorization alongside Cookie before application
dispatch. Existing Set-Cookie stripping, first-touch rate limiting and other
surface implementations are unchanged. Each narrow worker file then passed
30 tests. This change does not remove the old Rails dispatcher.

## Actual verification

Commands were run from the Edge clone using pnpm 12.0.0:

- `pnpm --dir <app|com|org>/core run test test/worker.test.ts`: Red and Green as
  above; final 30 tests passed per surface.
- `pnpm run check`: exit 0. Format, lint, type-aware lint, generated bindings,
  type checking, dead-code, twenty-worker validation, architecture, dependency
  synchronization and spelling checks passed. All twenty unit suites passed;
  each Core had 321 tests. Root invariants had 437 passed and one existing skip.
- The skipped root case is
  `test/compose-local-override-invariants.test.ts:150`, conditional on an available
  container engine. Its condition and the test were not changed. This result is
  not reported as a zero-skip full suite.
- `pnpm --dir <app|com|org>/core run test:api`: all three self-hosted local Hurl
  suites passed, four files and 22 requests per surface, 66 requests total. They
  cover existing status, security-header, standard and title contracts. They do
  not inspect the internal application Request or prove authentication continuity.
- Edge `git diff --check`: PASS; tracked dirty files remained exactly the six
  intended worker/test files after install, type generation and these checks.

## Limits and conflicting historical contract

Current Edge ADR 007 and worker/core-dispatch sources still implement Workers
VPC forwarding to Rails. The health route also probes Rails server-side. These
require reconciliation with the approved browser-owned connection contract;
this narrow credential removal does not claim that the target architecture is
complete. Existing production routing and dispatcher withdrawal remain a separate
deployment gate. No Cloudflare, AWS, DNS, WAF, Tunnel or routing setting changed.

No browser, authenticated Rails/Edge integration, refresh continuation, build,
bundle-size or coverage command ran in this slice. The unit-test pass does not
claim the separate 100% coverage gate. Core browser state, stale response defense,
dispatcher retirement and the refresh approval boundary remain unfinished.
