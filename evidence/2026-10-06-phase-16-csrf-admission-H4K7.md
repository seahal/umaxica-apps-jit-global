# Phase 16 verification

Commit: `bfe569a162078df62e8e3b3011367840780e3078`

The worktree was already uncommitted and remained dirty; unrelated changes were preserved.

Targeted commands run against the isolated PostgreSQL manifest
`tmp/auth-boundary-isolated-20261003auth6f3.json` with one worker:

- Binding models, coordinator, issuer, purgers and CSRF invariant tests: `43 runs, 402 assertions, 0 failures, 0 errors, 0 skips`.
- Auth admission boundary exchange: `9 runs, 52 assertions, 0 failures, 0 errors, 0 skips`.
- Receiver-local social CSRF exchange: `4 runs, 17 assertions, 0 failures, 0 errors, 0 skips`.
- Restart of a redeemed step-up ceremony: `1 run, 4 assertions, 0 failures, 0 errors, 0 skips`.
- Zeitwerk check: `All is good!`.

The older local-authentication boundary tests still encode the pre-D82 direct/local-admission and
status-303 assumptions; their failures are retained for subsequent contract updates and are not
counted as a passing Phase 16 result.

Browser-only cookie/SameSite/CSP enforcement remains NOT VERIFIED as required by the plan.

## Takeover verification, 2026-10-07

Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`; inherited and current implementation changes
were uncommitted. All commands used the agent-owned `20261007fresh3` PostgreSQL manifest and one
worker, never shared/production databases.

- Admission CSRF transport, redemption input, OIDC result browser binding, ceremony boundary and
  real Ticket concurrency: 174 runs/2,388 assertions, no failures/errors/skips.
- Coordinator, binding models, Step-Up/bootstrap issuers, purger, cancellation and opaque store:
  78 runs/921 assertions, no failures/errors/skips.
- Real Base-origin APP/COM signup and ORG Entra/Passkey root completion, receiver-local social
  completion and protocol CSRF: 11 runs/394 assertions, no failures/errors/skips. ORG handoff's
  pre-root completed-flow requirement first failed the real journey; it now uses the existing
  evidence-ready predicate without removing operator policy or issuing a root on Auth.
- CSRF notification/subscriber selection: 10 runs/31 assertions, no failures/errors/skips. Old
  fixtures stopped at admission or the Base RP unsafe-request guard; the repaired fixture targets
  the public Auth attachment receiver. Assertions about emission, count and redaction remain.
- Fourteen changed takeover Ruby files passed scoped RuboCop; scoped diff checks passed. These
  are not the plan's comprehensive Final Verification.

Middleware now reads D-80's standard ApplicationController verification strategy; the framework
base's strict default is unchanged. Real missing-header Entra
initiation exposed missing Rails instrumentation metadata and a removed exception alias in the
pinned CSRF gem. The replacement adapter invokes the unchanged inherited Rails predicate,
supplies only current metadata/exception, and keeps rejection taxonomy non-disclosing. Provider
GET callbacks and state/nonce/PKCE contracts are unchanged under the user's explicit direction.
User-deferred OIDC cancellation remains unimplemented; browser-only checks remain NOT VERIFIED.

The intermediate global-strategy change failed the strict-framework-default invariant (the five-file
settings/invariant command completed 67 runs/329 assertions, one failure). Root-policy delegation
replaced that global change; the invariant and real root/CSRF selection then passed 15 runs/374
assertions, no failures/errors/skips. The invariant test was not changed or weakened. The settings
controller cases in the first selection passed; their deeper OTP lifecycle coverage remains open.
