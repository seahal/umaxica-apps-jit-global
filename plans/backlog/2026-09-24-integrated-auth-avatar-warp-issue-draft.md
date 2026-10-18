# Local issue draft: Integrated Auth, Avatar, Warp, and Base Dashboard

**State:** Draft only. No GitHub issue was created or updated.
**Canonical implementation plan:** [Integrated Auth, Avatar, Warp, and Base Dashboard Implementation Plan](2026-09-24-integrated-auth-avatar-warp-plan.md)
**Local execution record:** [2026-09-25 verification and blocker evidence](../../evidence/2026-09-25-integrated-auth-avatar-warp-H7J4.md)

## Goal

Complete the twelve original requests and two additional requests in the canonical plan. Preserve the
current Base/Auth authority boundary, app/com/org trust separation, public protocols, persistence
contracts, and explicit residual gates. Treat the phases as dependency groups, not a mandatory
serial schedule. Start each unfinished slice when its direct dependencies are met and verify existing
implementation against its acceptance criteria before changing it.

## Workstream map

1. Critical owner and regional-client decisions — retain the approved six surface-local mappings and
   keep missing regional host/audience inputs fail-closed.
2. Avatar ownership and Group membership — use the adopted owner authority, lifecycle, and transfer
   contracts; do not infer owner authority from legacy bindings, membership, or assignment data.
3. Org authentication policy — preserve ordinary Entra sign-in and the separate emergency Passkey
   path; do not add self-service registration or JIT creation.
4. Base → Auth → Base primary authentication — keep Base authoritative and Auth ceremony-only;
   preserve the accepted, narrowly retryable result-finalization contract.
5. Cross-surface findings — implement F1–F9 and F11–F15 as specified. F10 billing/billings route
   naming and F15 redirect-only shims remain explicitly deferred.
6. Avatar moniker lifecycle — separate Avatar's temporal moniker from Persona display names; keep
   local migration work distinct from applying destructive changes to real data.
7. App emergency Credential and RecoveryPasscodes — preserve the temporary app-only Credential
   contract, durable concurrent-use exclusion, and the separate RecoveryPasscode contract.
8. Palm → Base → Auth → Base → Palm sign-out — keep the completion capability one-shot and mutation
   on the existing explicit routes.
9. www-jp anomaly re-audit — recheck only after relevant local changes and report historical
   observations as stale when they no longer reproduce.
10. Monotonic Auth ceremonies and Turnstile — validate ceremony authority before Siteverify, keep
    server-side verification, atomic bounded attempts, and fail-closed unknown outcomes.
11. Final Base/Auth architecture — remove executable Auth RP authority and preserve Base as the
    physical Authorization Server.
12. OAuth authorize rate limits — enforce IP, browser/client, then client/redirect-host; return 429
    for rejection and 503 for unavailable, erroneous, missing, or malformed counter results.
13. Side/Wide → Warp — rename classified internal Rails names and approved configuration keys while
    preserving public FQDNs/paths and protocol or persisted `side` identifiers.
14. Authenticated Base Dashboard navigation — display selected Persona name and its associated image,
    followed by Preference, Switcher, and Logout; implement the requested sign-out and Preference
    return behavior as read-only navigation. Preserve the narrow one-time RecoverySecret receipt
    consumption exception and keep approved protocol callbacks separately bounded.

The full acceptance conditions, app/com/org symmetry requirements, tests, and protected contracts
remain in the canonical plan and its source request map. This summary does not replace or narrow them.

## Execution and gates

- GitHub, cloud/provider accounts, external RP registration, production keys, and live deployments
  are outside this local task. Issue absence is not a blocker.
- Missing production keys, regional registration, real-data inventory disposition, or live cutover
  block only the operations that depend on them. They do not block unrelated local implementation,
  synthetic-data tests, or static verification.
- Do not guess owners, hosts, audiences, keys, or authorization state. Do not add a fallback,
  bypass, or success stub to pass a gate.
- Do not add environment variables or a new mandatory Valkey dependency to the normal Rails test
  suite. Record a service check as unrun when its configured service is unavailable; do not count a
  stubbed test as service verification.
- Keep `F10` and `F15` deferred as recorded in the canonical plan. Do not remove any acceptance
  condition from the original source requests.

## External follow-up only

After the local changes and evidence are reviewable, a project owner may separately decide whether
to register or update a GitHub issue, apply reviewed data changes, provision production keys, perform
regional registration, or deploy. This draft does not authorize any of those writes.

## Local execution snapshot (2026-09-25)

- The integrated changes pass the full local Rails suite (11,686 runs, 74,825 assertions, 0
  failures/errors, 8 skips), focused route and RecoverySecret contracts, Zeitwerk, object-placement
  checks, and the changed frontend tests. The worktree was already
  dirty and remains uncommitted; see the evidence record for counts and exact commands.
- Eight full-suite tests were skipped. Six require `AUTH_STATE_REDIS_URL`; one requires the Flipper
  UI mount; one targets a nonexistent single-use-token model. No skipped test is reported as passed.
- Base Dashboard identity name and navigation are verified. Avatar image delivery remains blocked on
  an approved delivery/absence contract. Task-specific GET return links are read-only; a broader
  claim that every repository GET is protocol-write-free or that CSRF-protected HTML emits no session
  state is not made without a current contract and request evidence.
- Regional US activation, production Warp keys, real-data owner/moniker/legacy-row cutover,
  production anomaly re-audit, GitHub registration, and deployment remain external or data gates.
- F10 billing/billings naming and F15 redirect-only shims remain deferred, as do the Phase 4 F1
  `session_nonce` and pre-reveal top-up design questions. The full 12+2 mapping and original
  acceptance criteria remain in the canonical plan.
