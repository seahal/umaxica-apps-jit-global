# Email Sign-In OTP Ceremony Binding

## Status

**BACKLOG — NOT STARTED** (2026-10-11).

The [accepted security ADR](../../adr/email-sign-in-otp-ceremony-binding-and-risk-acceptance.md)
defines the target. This backlog captures deferred implementation and verification work, not an
approved implementation schedule. Existing related controls do not establish completion.
The [local source baseline](../../docs/security/email-otp-ceremony-security-boundary.md) examined
`feature` at `65e2f0f750b6262da38eb9022f9bf71e47a3f3a2` and re-inspected it unchanged at
`a1ec83a7384a424c97671356268ec5c4ad8347d4`, with pre-existing unrelated changes in the worktree.

## Cycle and decision prerequisites

Future implementation cycle: **TBC**. The
[current-cycle Auth/Xper freeze](../../adr/defer-auth-xper-transient-workflow-redesign.md) remains
effective. Its D-82 exception covers the specified Base/Auth admission exchange only; this plan
does not extend it to OTP workflow redesign. Before selection, resolve the scope conflict and
record any necessary accepted amendment: **TBC**. Then use the repository spec lifecycle for the
accepted implementation scope. No implementation, migration, tests or deployment starts here.

## Future work

1. Reinspect both APP and COM issuance/verification paths against the ADR. Preserve existing
   ceremony-specific challenge and Contact/parent locking; prove OTP issuance belongs to the
   authorized Auth Ceremony and corresponding Rails Session continuity. Distinguish the Base
   browser admission nonce, Auth SID and Rails Session. Do not assume the Rails Session ID is a
   stable secret. Choose nonce/server-reference, keying, persistence, rotation and comparisons:
   **TBC**.
2. Define generation and supersession semantics, including the theoretical case of repeated
   numeric values in different random generations. Prove replaced generations cannot authenticate
   another ceremony or become current again. Preserve expiry caps, candidate limits and shared
   failure budgets across issuance, resend, refusal and restart.
3. Preserve atomic consumption under database locks. Reconcile current `already_verified`
   continuation with strict post-consumption refusal, without treating an authorized handoff retry
   as fresh OTP proof or issuing a second session. Specify partial-failure/retry ownership: **TBC**.
4. Inspect resend endpoints and encrypted resend-state authorization together. Current state is
   purpose-bound to the Auth SID digest and includes Contact/owner facts, but omits explicit
   ceremony ID/generation. Decide whether more correlation is needed: **TBC**. Prove no ceremony
   transfer, detached binding, downgrade or unauthorized issuance, including concurrent resend
   against verification and replaced state.
5. Specify missing/stale/rotated/inconsistent cookie and Rails Session behavior, expiry,
   cancellation, revocation and explicit restart. Refuse invalid continuity before evidence or
   issuance. Preserve non-disclosing errors, CSRF, admission, rate limits, cookie security and
   request-control order. Protect OTP/binding material across logs, jobs, responses and delivery.
6. Prove Base handoff protects original browser/parent correlation, session-limit/cooldown gates,
   finalization and session authority. Auth-cookie possession alone grants no Base or RP authority.
   Preserve independent surfaces and existing authentication requirements.
7. Assess persistence/forward-migration needs and recovery consequences: **TBC**, including whether
   current challenge storage suffices. No schema or migration design is selected by this plan.
8. When authorized in a future cycle, test through public request boundaries with real persistence:
   success, refusal, authorization, malformed/missing/empty input, nearest reachable values below,
   at and above expiry/limit boundaries, Browser A/B separation, concurrent verification, concurrent
   resend and verify/resend races. Confirm at most one consumption/evidence transition and no
   unauthorized session issuance. Record actual future results against their revision.

## Future acceptance scenarios

These scenarios are recorded for future tests. None was written or executed in this documentation
task. A/B refer to independently admitted ceremonies and browser continuity, not just different
tabs with the same cookies.

| Scenario | Setup/action | Required future result |
| --- | --- | --- |
| A | A issues a code; independently admitted B for the same account/email submits A's code. | B is refused without authentication evidence or session issuance. |
| B | A submits its own valid code. | One successful consumption and authorized continuation. |
| C | A valid code is submitted twice, sequentially and concurrently. | At most one successful consumption; consumed OTP is never accepted as new proof. Retained-result/handoff retry reconciliation is TBC. |
| D | A code is replaced/reissued. | Superseded generation cannot authenticate any ceremony; failure budget is preserved. |
| E | Cookie/continuity secrets are missing, stale, rotated, canceled or inconsistent. | Fail closed; no evidence or session issuance from invalid continuity. |
| F | Resend uses state from another or invalid ceremony. | No unauthorized issuance or binding transfer. Cover expiry, rotation, generation and concurrent calls. |
| G | Adversary starts legitimate B and gets B's own code through external mailbox compromise. | Document that ceremony binding alone cannot prevent this; no test claims elimination of AR-OTP-002. |

## Non-goals and related tracks

APP/COM Sign-Up Email/Telephone and Step-Up Email retain their separate ticket/transaction models;
only consistency review is included. Telephone Sign-In or Step-Up is excluded. General MFA
redesign, Passkey credential-management hardening, account recovery, shared Auth/Xper framework,
device-bound browser session implementation and external rollout are separate tracks.

[Auth/Xper transient workflow redesign](auth-xper-transient-workflow-redesign.md) remains separately
deferred. [OTP observability remediation](../../adr/otp-observability-secret-exposure-remediation.md)
and [realm-separated identifiers](../../adr/realm-separated-identifiers-and-dead-history.md) retain
their own contracts. This work preserves them; it does not reopen or replace those tracks.

AR-OTP-001 is accepted only for the current design cycle; AR-OTP-002 covers external mailbox
compromise only. Persuaded OTP disclosure acceptance remains **TBC**. Neither acceptance waives
cross-ceremony refusal, one-time consumption, admission, internal secret protection, assurance
accuracy or Base authority boundaries.

## Supplemental documentation capture

Supplied title: **APP/COM Email Sign-In OTP Originating Ceremony Binding**.
Date recorded in supplied material: **2026-10-12**; discussion: **2026-10-11**.
Status remains **BACKLOG — NOT STARTED**, without implementation authorization.
The date is retained metadata, not a claim of checks on that date. The supplied public baseline
`6fa6867d44b5499632079775cb0fb22cbfddd339` is historical and must be reconciled with the later
local findings above. The [historical boundary capture](../../docs/security/email-sign-in-otp-ceremony-security-boundary.md)
preserves that distinction.

### Objective and scope

Prevent an APP/COM Email Sign-In OTP issued in A from authenticating distinct B, while preserving
registered-email verification, atomic consumption, admission, expiry, rate limits, privacy and
Auth/Base authority. This concerns issuance association, not a claim that the historical locked
verifier failed to clear consumed OTPs.

Include surface-local credentials, ceremony/Rails continuity, issuance, verification, consumption,
resend, restart/cancellation, evidence handoff refusal and future tests. Exclude code changes in this
cycle; universal MFA/Passkey requirements; changes to Email OTP's product exception; Sign-Up and
Step-Up redesign; Telephone login/Step-Up; ORG; Edge/Hono; generic Auth/Xper redesign; token authority;
and phishing acceptance beyond the ADR.

### Activation inventory and design questions

| Component | Review at activation |
| --- | --- |
| Auth ceremony context/cookie/session | Rotation, expiry, terminal states, local versus OIDC admission |
| APP/COM sign-in controllers | Issue-time ceremony reference and verification matching |
| APP authentication state / COM session keys | Independent continuity nonce and session reset |
| Current challenge and historical CommonOtp/OtpLockable | Atomicity, preserved budgets, stale generations; do not restore removed code |
| Resend state/resender | Current SID-purpose binding, original ceremony/generation, no budget reset |
| AuthenticationSessionCommitter and handoff | Refusal yields no evidence or Base session |
| Surface credential/ticket owners | Persistence choice and APP/COM database isolation |

Resolve before implementation:

1. Choose surface-local challenge versus credential-backed state without making a credential a
   session authority; document transactions spanning ticket and credential databases.
2. Select unpredictable ceremony identifier/nonce and any separate protected Rails nonce;
   justify its contract without assuming `session.id` stability.
3. Define canonical ceremony identity through admission, SID rotation, Rails reset, simultaneous
   tabs and restart; prevent false acceptance or binding transfer.
4. Choose global versus per-ceremony active codes, invalidation/recovery UX and distributed limits;
   competing issuances must not be interchangeable.
5. Keep verification/consumption one authoritative transition; define partial-write refusal,
   crash, rollback and retry across databases.
6. Require live authorized resend continuity and matching original or explicitly replaced
   generation, preserving failure budgets and delivery safeguards.
7. Define evidence recording, challenge closure and Base completion order; no resurrection,
   duplicate proof or multiple unauthorized Browser Sessions.
8. Define sanitized event references/one-way digests; exclude OTPs, emails, cookies, unredacted
   IDs/tokens and full request parameters from logs and metrics.
9. Review non-enumerating errors, multi-browser/IP throttling, issuance denial of service,
   expired/missing state, and delivery/queue failure recovery.
10. Resolve implementation scope against the Auth/Xper freeze and D-82-only exception.

### Supplemental regression catalog

Future tests use isolated cookie jars, fake outbound adapters and existing test PostgreSQL/Valkey.
No real email/SMS, new tests or test execution is authorized by this documentation capture.

| ID | Scenario | Required result |
| --- | --- | --- |
| OTP-BIND-01 | A issues X; separately admitted B for same email submits X | B refused; no Auth evidence or Base session |
| OTP-BIND-02 | A submits X under correct live binding | Exactly one consumption and authorized continuation |
| OTP-BIND-03 | A submits X twice sequentially/concurrently | At most one consumption; reconcile retained handoff evidence |
| OTP-BIND-04 | X replaced by Y | X refused everywhere; Y only in correctly bound ceremony; numeric-generation collisions require explicit semantics |
| OTP-BIND-05 | Auth/Rails state absent, expired, canceled, rotated, superseded or mismatched | Refusal before evidence; no fallback |
| OTP-BIND-06 | A's encrypted resend state used in B or without authorized continuity | No issuance, retargeting or transfer |
| OTP-BIND-07 | APP state/code used on COM or conversely | Surface isolation and refusal |
| OTP-BIND-08 | Five wrong guesses, concurrent guesses, resend after failure, multiple IPs | No budget reset/limit bypass; generic refusal; test actual policy boundaries |
| OTP-BIND-09 | Correct OTP; actor becomes login-forbidden or admission invalid before consumption/handoff | No accepted result/session |
| OTP-BIND-10 | Crash/transaction error between verification, consumption and finalization | No duplicate proof, resurrection, unauthorized session or unsafe retry |
| OTP-BIND-11 | Same-browser tabs and interrupted reissue | Documented deterministic UX; no cross-ceremony acceptance |
| OTP-BIND-12 | B gets its own issued OTP through external mailbox compromise | Document accepted dependency; do not claim binding prevents it |

Tests with stolen necessary continuity secrets plus valid OTP may demonstrate AR-OTP-001's bearer
limitation rather than a violation. Phishing disclosure without mailbox compromise remains TBC.

### Activation and rollout gates

Before accepting implementation into `specs/` (the repository has no `plans/active/`):

- Re-inventory local HEAD/ADRs and check for equivalent delivered work.
- Resolve owner, consistency, rotation, resend and multi-ceremony policy; amend accepted decisions
  explicitly if their contract changes.
- Assign responsible owner, formal residual-risk review date and milestone, all currently TBC.
- Authorize Auth implementation scope under the freeze, keeping unrelated changes out.
- Agree on privacy-safe audit evidence, controlled rollout/rollback and no-downgrade behavior.

Future completion evidence must identify code paths, per-surface test and concurrency results,
updated stable docs and OTP-BIND-01–12 dispositions. Until then, the target is unverified.

Related records: [Base/Auth](../../adr/base-auth-ceremony-and-seven-rp-boundary.md),
[Auth/Xper deferral](../../adr/defer-auth-xper-transient-workflow-redesign.md),
[historical race fixes](../../adr/email-otp-race-condition-fixes.md), [OTP audit](../../docs/security/otp-audit.md),
[credential abuse controls](../../docs/security/credential-abuse-rate-limits.md),
[rate-limit backlog](credential-abuse-rate-limit-policy.md), and [OTP lifetime backlog](out-of-band-otp-lifetime.md).

This record starts no implementation, migration, test development, CI change or token/session
configuration change.
