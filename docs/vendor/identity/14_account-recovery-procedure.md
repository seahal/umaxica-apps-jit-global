---
title: Account Recovery Procedure
status: rfi-draft
version: "2026-06-24-r4"
audience:
  - SIer
  - security-vendor
  - internal-architecture
  - support-operations
owner: internal-architecture-owner
last-reviewed: 2026-06-24
source-of-truth: current-repository-evidence
confidentiality: internal-vendor-shareable
related-audit-ledger: docs/vendor/identity/11_decision-register.md
---

# Purpose

Define the recovery procedure, operator workflow, state machine, abuse protection, audit
requirements, acceptance criteria, and SIer scope for account recovery — specifically MFA reset and
catastrophic credential loss. This document is the normative reference for any SIer or internal team
that implements, extends, or assesses account recovery behavior.

# ⚠ Critical Current State Warning

**MFA reset UI is currently DISABLED.**

The `create` action in `sign/app/settings/mfa/resets_controller.rb` redirects with
`reset_unavailable`. `docs/security/mfa-reset-account-recovery.md` describes the intended design
(72h cooling, operator approval, credential revocation, re-bootstrap), but this design is not yet
deployed as a user-facing self-service flow.

**This is a Procurement Blocker** (GAP-NEW-006/007, DEC-009). MFA reset and catastrophic recovery
MUST NOT be treated as completed capabilities in any RFI/RFP response.

Five prerequisites must be satisfied before MFA reset UI may be enabled:

1. Account Recovery Runbook (this document)
2. MFA Reset State Machine (§5)
3. Abuse Protection (§7)
4. Audit Requirements (§8)
5. Acceptance Criteria (§12)

---

# 1. Document Status

| Field           | Value                                                                                                           |
| --------------- | --------------------------------------------------------------------------------------------------------------- |
| Status          | rfi-draft                                                                                                       |
| Owner           | internal-architecture-owner                                                                                     |
| Audience        | SIer, security-vendor, internal-architecture, support-operations                                                |
| Confidentiality | internal-vendor-shareable                                                                                       |
| Last reviewed   | 2026-06-24 (Round 4 audit)                                                                                      |
| Related docs    | `docs/security/mfa-reset-account-recovery.md` (intended design), `docs/vendor/identity/11_decision-register.md` |

---

# 2. Current State

| Item                                              | State                                                                            | Source                                                        |
| ------------------------------------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| MFA reset UI                                      | **DISABLED** — `create` action redirects with `reset_unavailable`                | `sign/app/settings/mfa/resets_controller.rb` (CODE, verified) |
| MFA reset intended design                         | Documented (72h cooling, operator approval, credential revocation, re-bootstrap) | `docs/security/mfa-reset-account-recovery.md`                 |
| Catastrophic recovery path (all credentials lost) | **UNDEFINED**                                                                    | No document or code covers this case                          |
| Recovery passcode stock                           | min=2, target=10 per actor                                                       | `app/services/recovery_passcode_top_up.rb`                    |
| Recovery passcode rate limit                      | **ABSENT** — no rate limit or attempt lockout                                    | Known gap (DEC-005, GAP-NEW-001)                              |
| Identity verification for operator recovery       | **OPEN BLOCKER** — specific verification steps not defined                       | Not evidenced in repository                                   |
| Administrative lock/unlock                        | Exists                                                                           | Operator capability confirmed                                 |
| Audit events for recovery lifecycle               | Partially defined in `docs/security/mfa-reset-account-recovery.md`               | Not fully implemented yet                                     |
| Audit log DB-level immutability                   | **ABSENT**                                                                       | Separate blocker (NR-004, GAP-002)                            |

---

# 3. Non-negotiable Principles

The following principles are invariants. They cannot be relaxed by SIer, operator, or product
decision without a new accepted ADR.

| #     | Principle                                                                                                                   |
| ----- | --------------------------------------------------------------------------------------------------------------------------- |
| P-001 | Account recovery is a high-risk identity ceremony. It MUST NOT be treated as routine user self-service.                     |
| P-002 | MFA reset MUST NOT be enabled as a UI-only feature. Operator workflow and audit evidence are prerequisites.                 |
| P-003 | Recovery MUST require operator-mediated approval unless a future ADR defines a safe, audited self-service ceremony.         |
| P-004 | Recovery MUST produce durable audit evidence for every state transition.                                                    |
| P-005 | Recovery MUST include abuse protection (rate limiting, per-account cooldown, suspicious request detection).                 |
| P-006 | Recovery MUST include a rejection / denial path that leaves the account unchanged.                                          |
| P-007 | Recovery MUST notify the account through every safe registered notification channel. No silent recovery.                    |
| P-008 | Recovery MUST NOT allow the support workflow to become an account takeover vector.                                          |
| P-009 | 72-hour cooling period is mandatory between request creation and approval. No operator can bypass it.                       |
| P-010 | Approval does NOT grant an authenticated session. Re-authentication is required after recovery.                             |
| P-011 | Successful recovery MUST revoke all active sessions and refresh token families.                                             |
| P-012 | Identity verification for operator-mediated recovery must be explicitly defined. "We confirmed the user" is not sufficient. |

---

# 4. Recovery Scenarios

The following table defines how each scenario is handled. Scenarios without a defined resolution are
marked as OPEN BLOCKER.

| #     | Scenario                                            | Disposition                                            | Required Actor                           | Required Evidence                             | Cooling Period                                | User-visible Result                                  | Audit Events                                                                                                                 | Notes                                                                                                                          |
| ----- | --------------------------------------------------- | ------------------------------------------------------ | ---------------------------------------- | --------------------------------------------- | --------------------------------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| S-001 | Valid session; lost one of multiple MFA methods     | Self-service removal of unused method                  | User (authenticated)                     | Current MFA method + session                  | None                                          | Method removed; remaining methods intact             | `mfa_removed`, `credential_destroyed`                                                                                        | Standard settings flow. No recovery needed.                                                                                    |
| S-002 | Has email/SMS; lost passkey but has TOTP            | Standard sign-in with TOTP; remove passkey in settings | User (authenticated via TOTP)            | TOTP verification                             | None                                          | Passkey removed; TOTP remains                        | `mfa_removed`                                                                                                                | Normal authenticated flow.                                                                                                     |
| S-003 | Has valid recovery passcode; lost all other MFA     | Use recovery passcode during ceremony                  | User                                     | Recovery passcode (single-use)                | None                                          | MFA reset to UNCONFIGURED; must re-register          | `recovery_passcode_consumed`, `credential_destroyed`, `mfa_reset`                                                            | Recovery passcode is the designed fallback. [KNOWN GAP: no rate limit]                                                         |
| S-004 | Lost passkey + TOTP + all recovery passcodes        | Operator-mediated MFA reset                            | User + Operator                          | Identity verification (OPEN — see §4a)        | 72 hours                                      | All MFA revoked; must re-register via bootstrap flow | `recovery_requested`, `identity_verification_*`, `operator_approved`, `mfa_reset`, `credential_destroyed`, `session_revoked` | **This is the core MFA reset flow. UI currently DISABLED.**                                                                    |
| S-005 | Lost email/phone AND all MFA AND all passcodes      | Catastrophic recovery                                  | **OPEN BLOCKER**                         | **UNDEFINED**                                 | **UNDEFINED**                                 | **UNDEFINED**                                        | **UNDEFINED**                                                                                                                | **[BLOCKER]** No defined path exists for total identity loss. This requires policy decision and ADR before any implementation. |
| S-006 | Account suspected compromised                       | Operator-initiated lock + investigation + recovery     | Operator                                 | Abuse signal or user report                   | Operator discretion (minimum 72h recommended) | Account locked; recovery path after investigation    | `account_locked`, `operator_action`, `session_revoked`, recovery lifecycle events                                            | Distinct from user-initiated MFA reset. Priority is containment.                                                               |
| S-007 | Account suspended or administratively locked        | Operator unlock with review                            | Operator                                 | Review of lock reason + identity verification | As determined during lock                     | Account unlocked with notification                   | `account_unlocked`, `operator_action`                                                                                        | May use administrative lock/unlock capability (confirmed).                                                                     |
| S-008 | Operator-initiated recovery for verified user       | Operator-mediated MFA reset                            | Operator + second operator (if required) | Identity verification + risk review           | 72 hours                                      | Same as S-004                                        | Same as S-004 + `second_operator_approval` if applicable                                                                     | Second-operator approval requirement to be confirmed in policy.                                                                |
| S-009 | Fraudulent recovery request (impersonation attempt) | Reject + alert                                         | Operator                                 | Abuse detection signals                       | N/A                                           | Request denied; existing account unchanged           | `recovery_rejected`, `abuse_detected`, `operator_action`                                                                     | See §7 abuse protection.                                                                                                       |
| S-010 | Deceased / inactive account                         | **OUT_OF_SCOPE**                                       | —                                        | —                                             | —                                             | —                                                    | —                                                                                                                            | No policy defined. Mark as out of scope until explicitly addressed by product/legal.                                           |

## 4a. Identity Verification — OPEN BLOCKER

For operator-mediated recovery (S-004, S-005, S-007, S-008), the specific identity verification
steps are **not yet defined**. This is a known blocker.

Current status: The repository confirms that operator approval is required after 72h cooling, but
the method by which an operator verifies the user's identity before initiating recovery is not
specified in any document or implemented in any code.

**Required before MFA reset UI can be enabled:**

- Define acceptable identity verification methods (e.g., government ID, video call, OTP to verified
  secondary contact, hardware key, biometric)
- Define which methods are required vs. optional
- Define how verification evidence is recorded (audit trail)
- Define who reviews verification evidence and approves it
- Define what happens when verification fails or is inconclusive

Until this is defined, operator-mediated recovery should not be deployed in production without a
compensating control (e.g., requiring two-operator approval, escalation to a security team).

---

# 5. MFA Reset State Machine

## States

| State                           | Description                                                                    |
| ------------------------------- | ------------------------------------------------------------------------------ |
| `not_requested`                 | No active reset request exists for this account.                               |
| `request_received`              | User or operator has submitted a recovery request.                             |
| `identity_verification_pending` | System is awaiting identity verification evidence.                             |
| `operator_review_pending`       | Cooling period active (72h). Request awaits operator review.                   |
| `cooling_period_active`         | 72-hour mandatory cooling period is in progress.                               |
| `approved_pending_execution`    | Operator has approved. Credential revocation not yet executed.                 |
| `rejected`                      | Operator or system has denied the request. Account unchanged.                  |
| `cancelled`                     | User has cancelled while still having access to the account.                   |
| `expired`                       | Request exceeded maximum lifetime without approval.                            |
| `executed`                      | Credentials revoked. Account in UNCONFIGURED MFA state. Re-bootstrap required. |
| `post_recovery_monitoring`      | Recovery complete. Monitoring period active for abuse detection.               |
| `locked_for_abuse`              | Request or account flagged for abuse. Further attempts blocked.                |

## Transitions

| From                            | To                              | Trigger                                                   | Actor                               | Guard Condition                                                         | Side Effects                                                                                   | Audit Event                                            | Timeout                              |
| ------------------------------- | ------------------------------- | --------------------------------------------------------- | ----------------------------------- | ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | ------------------------------------------------------ | ------------------------------------ |
| `not_requested`                 | `request_received`              | User or operator submits request                          | User or Operator                    | Single active request per account (duplicate blocked)                   | Notify all safe channels; start cooling timer                                                  | `recovery_requested`                                   | —                                    |
| `request_received`              | `identity_verification_pending` | System initiates verification                             | System                              | Identity verification method is defined (OPEN BLOCKER)                  | Identity verification flow triggered                                                           | `identity_verification_started`                        | —                                    |
| `request_received`              | `cooling_period_active`         | Immediate if verification not required (OPEN: policy TBD) | System                              | Verification complete or not required                                   | 72h cooling timer started; notifications sent                                                  | `cooling_started`                                      | 72 hours from creation               |
| `identity_verification_pending` | `cooling_period_active`         | Verification evidence accepted                            | Operator                            | Evidence meets defined threshold                                        | 72h timer restarted from verification                                                          | `identity_verification_succeeded`, `cooling_started`   | Configurable (OPEN)                  |
| `identity_verification_pending` | `rejected`                      | Evidence insufficient or absent                           | Operator                            | Verification failure                                                    | Notify user; account unchanged                                                                 | `identity_verification_failed`, `recovery_rejected`    | —                                    |
| `cooling_period_active`         | `operator_review_pending`       | 72h elapsed                                               | System (timer)                      | 72h has elapsed since `request_received` (or verification succeeded)    | Notify operator queue                                                                          | `cooling_expired`, `review_ready`                      | —                                    |
| `operator_review_pending`       | `approved_pending_execution`    | Operator approves                                         | Operator (not the requesting actor) | 72h elapsed; identity verified; no active abuse flag                    | Record approval + approver identity                                                            | `operator_approved`                                    | Configurable expiry (OPEN)           |
| `operator_review_pending`       | `rejected`                      | Operator denies                                           | Operator                            | Operator judgment or policy violation                                   | Notify user; account unchanged                                                                 | `recovery_rejected`, `operator_action`                 | —                                    |
| `approved_pending_execution`    | `executed`                      | System executes credential revocation                     | System                              | Approval is valid and not expired                                       | Revoke passkeys, TOTP, passcodes; set MFA_UNCONFIGURED; revoke all sessions + refresh families | `mfa_reset`, `credential_destroyed`, `session_revoked` | —                                    |
| `executed`                      | `post_recovery_monitoring`      | Recovery complete                                         | System                              | Execution confirmed                                                     | Start monitoring window; require re-auth                                                       | `recovery_completed`                                   | Configurable monitoring window       |
| `any`                           | `cancelled`                     | User cancels (while still having session)                 | User (authenticated)                | User still has an active authenticated session with current credentials | Stop cooling timer; notify; restore normal state                                               | `recovery_cancelled`                                   | —                                    |
| `any`                           | `expired`                       | Maximum request lifetime exceeded                         | System (timer)                      | Lifetime limit reached without terminal state                           | Notify user; account unchanged                                                                 | `recovery_expired`                                     | Max lifetime (OPEN — suggest 7 days) |
| `any`                           | `locked_for_abuse`              | Abuse detection triggered                                 | System or Operator                  | Abuse signal threshold met                                              | Block further attempts; alert operations team                                                  | `abuse_detected`, `account_locked`                     | Operator-released                    |
| `post_recovery_monitoring`      | `not_requested`                 | Monitoring window ends normally                           | System                              | No abuse signals during window                                          | Normal state restored                                                                          | `monitoring_completed`                                 | Configurable window                  |

## Invalid Transitions

Any state transition not listed above is invalid. The system MUST reject invalid transitions and
emit an audit event. Invalid transitions MUST NOT silently succeed.

SIer MUST implement explicit guard conditions for invalid transition rejection.

---

# 6. Operator Workflow

```
1. Recovery Request Received
   └─ System: Notify all verified channels immediately
   └─ System: Validate no duplicate active request (reject if exists)
   └─ System: Start 72h cooling timer

2. Identity Verification (OPEN BLOCKER — steps not defined)
   └─ Operator: Review identity evidence per defined method (method TBD)
   └─ Operator: Record verification outcome
   └─ System: Emit identity_verification_succeeded or identity_verification_failed

3. Operator Queue (after 72h)
   └─ Operator 1: Reviews request in authorized org workflow
   └─ Operator 1: MUST NOT be the requesting actor
   └─ Operator 1: Verifies cooling period elapsed, identity verified, no abuse flags
   └─ Operator 1: Approves or rejects

4. Second-Operator Approval (if required by policy — OPEN: requirement TBD)
   └─ Operator 2: Independent review
   └─ Operator 2: MUST NOT be Operator 1

5. Approval
   └─ System: Execute credential revocation atomically
      ├─ Revoke all passkeys
      ├─ Revoke all TOTP credentials
      ├─ Revoke all recovery passcodes
      └─ Set MFA status to UNCONFIGURED
   └─ System: Revoke all active sessions
   └─ System: Revoke all refresh token families
   └─ System: Emit all required audit events
   └─ System: Notify user via verified channels

6. Re-authentication Required
   └─ User: Must authenticate from scratch (recovery does not grant a session)
   └─ User: Must complete bootstrap flow to register new step-up method
   └─ Sensitive actions remain blocked until new MFA exists

7. Post-Recovery Monitoring
   └─ System: Monitor for unusual access patterns
   └─ Operations: Review if flagged

8. Rejection / Denial Path
   └─ System: Account left completely unchanged
   └─ System: Notify user of rejection
   └─ System: Emit recovery_rejected
   └─ If abuse signal: escalate to security team

9. Escalation
   └─ If operator cannot verify identity → escalate to security team
   └─ If abuse suspected → lock for abuse + alert
   └─ If catastrophic loss (no channels available) → OPEN BLOCKER (no defined path)
```

---

# 7. Abuse Protection Requirements

| #       | Requirement                                 | Implementation Candidate                                          | Status                                                   |
| ------- | ------------------------------------------- | ----------------------------------------------------------------- | -------------------------------------------------------- |
| ABU-001 | Rate limit recovery requests per account    | Max N requests per rolling window (N=OPEN)                        | OPEN — not implemented                                   |
| ABU-002 | Per-account cooldown after rejected request | Minimum 24h before next attempt (OPEN)                            | OPEN — not implemented                                   |
| ABU-003 | Per-IP throttling for recovery initiation   | Max N attempts per IP per hour                                    | OPEN — not implemented                                   |
| ABU-004 | Duplicate request blocked                   | Only one active request per account                               | Defined in `docs/security/mfa-reset-account-recovery.md` |
| ABU-005 | No silent recovery                          | All state transitions notify user via verified channels           | Defined in source doc                                    |
| ABU-006 | No bypass of cooling period                 | Cooling period is enforced by system, not operator-discretion     | Defined in source doc                                    |
| ABU-007 | No immediate credential reset               | Approval only authorizes; system executes after all guards pass   | Defined in source doc                                    |
| ABU-008 | Suspicious request detection                | Flag if: unusual IP, device, geographic location, timing          | OPEN — detection method not specified                    |
| ABU-009 | Operator abuse detection                    | Flag if operator approves unusually high volume of requests       | OPEN — not implemented                                   |
| ABU-010 | Notification to all verified channels       | Notify email, phone, in-product when available                    | Defined in source doc                                    |
| ABU-011 | Fraud escalation path                       | Suspicious or conflicting evidence → auto-reject + alert security | OPEN — escalation path not specified                     |
| ABU-012 | Recovery passcode rate limit (separate gap) | No rate limit currently exists                                    | **[KNOWN GAP, DEC-005]** — separate remediation item     |

---

# 8. Audit Requirements

All recovery-related audit events MUST comply with NR-004 (append-only or tamper-evident, no secrets
logged). The following events are binding.

**[BLOCKER]** Chronicle DB-level immutability is currently absent. Recovery audit events are
particularly critical because they represent high-risk account mutations. NR-004 remediation must be
in place before MFA reset is deployed in production (separate blocker, GAP-002).

| Event                             | Trigger                                | Required Fields                                                                       | Prohibited Fields                                 |
| --------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------- |
| `recovery_requested`              | User or operator submits request       | actor_id, account_id, timestamp, request_source (ip/device class), surface            | Cookie, session, request params                   |
| `identity_verification_started`   | Verification flow initiated            | actor_id, account_id, verification_method, operator_id, timestamp                     | Identity document content, raw evidence           |
| `identity_verification_succeeded` | Evidence accepted                      | actor_id, account_id, operator_id, method, timestamp                                  | Raw evidence content                              |
| `identity_verification_failed`    | Evidence rejected                      | actor_id, account_id, operator_id, failure_reason_class, timestamp                    | Raw evidence content                              |
| `cooling_started`                 | 72h timer starts                       | actor_id, account_id, cooling_start_time, cooling_end_time                            | —                                                 |
| `cooling_expired`                 | 72h elapsed                            | actor_id, account_id, elapsed_time, timestamp                                         | —                                                 |
| `review_ready`                    | Request enters operator queue          | actor_id, account_id, timestamp                                                       | —                                                 |
| `operator_approved`               | Operator approves request              | account_id, approver_operator_id, timestamp, request_id                               | —                                                 |
| `second_operator_approved`        | Second operator approves (if required) | account_id, approver_operator_id, timestamp                                           | —                                                 |
| `recovery_rejected`               | Operator or system denies              | account_id, operator_id (if applicable), rejection_reason_class, timestamp            | Raw reason detail if sensitive                    |
| `recovery_cancelled`              | User cancels                           | actor_id, account_id, timestamp                                                       | —                                                 |
| `recovery_expired`                | Request exceeds maximum lifetime       | actor_id, account_id, timestamp                                                       | —                                                 |
| `mfa_reset`                       | Credential revocation executed         | account_id, operator_id, revoked_method_types (not values), new_mfa_status, timestamp | Passkey private key, TOTP secret, passcode values |
| `credential_destroyed`            | Individual credential revoked          | account_id, credential_type, timestamp                                                | Credential value or secret                        |
| `session_revoked`                 | All sessions revoked post-recovery     | account_id, revoked_session_count, timestamp                                          | Session cookie or token values                    |
| `recovery_passcode_consumed`      | Recovery passcode used                 | account_id, timestamp, result                                                         | Passcode plaintext                                |
| `recovery_completed`              | Full recovery workflow done            | account_id, timestamp, operator_id                                                    | —                                                 |
| `abuse_detected`                  | Abuse signal threshold crossed         | account_id, signal_type, timestamp                                                    | —                                                 |
| `account_locked`                  | Account locked for abuse               | account_id, lock_reason_class, operator_id (if applicable), timestamp                 | —                                                 |
| `account_unlocked`                | Administrative unlock                  | account_id, operator_id, timestamp                                                    | —                                                 |
| `operator_action`                 | Any operator mutation on account       | account_id, operator_id, action_type, timestamp                                       | —                                                 |
| `monitoring_completed`            | Post-recovery monitoring window ends   | account_id, timestamp                                                                 | —                                                 |

---

# 9. Session and Token Effects After Recovery

When recovery is successfully executed, the following MUST occur atomically (or as close to atomic
as the system supports):

| Effect                                       | Required            | Notes                                                                      |
| -------------------------------------------- | ------------------- | -------------------------------------------------------------------------- |
| All active sessions revoked                  | Yes                 | For all surfaces. `session_revoked` event emitted.                         |
| All refresh token families revoked           | Yes                 | Entire family, not just the current token.                                 |
| Pending ceremony state invalidated           | Yes                 | Any in-flight ceremony using old credentials is invalidated.               |
| Re-authentication required                   | Yes                 | Recovery does NOT grant an authenticated session. User must sign in.       |
| Recovery passcodes regenerated               | Yes (if applicable) | New stock issued after MFA re-bootstrap. Old passcodes are destroyed.      |
| User notified through verified channels      | Yes                 | Email, SMS if available. In-product if session exists.                     |
| Account flagged for post-recovery monitoring | Yes                 | Monitoring window starts.                                                  |
| Operator approval expires after execution    | Yes                 | Approval is single-use.                                                    |
| New MFA required before sensitive actions    | Yes                 | `multi_factor_status_id` = UNCONFIGURED blocks step-up until re-bootstrap. |

---

# 10. SIer Scope

## What SIer May Implement (when prerequisites are met)

| Capability                           | Permitted Scope                                 | Constraints                                                                                                  |
| ------------------------------------ | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| MFA reset request UI (Sign surface)  | User-facing request initiation and cancellation | Must be disabled until all 5 DEC-009 prerequisites are satisfied (this document is one of them).             |
| Operator review UI (Org surface)     | Operator-facing approval / rejection workflow   | Must integrate with operator approval pipeline. Must enforce 72h cooling. Must enforce approver ≠ requestor. |
| Notification integration             | Sending notifications via registered channels   | Must notify ALL available verified channels. Must not allow silent recovery.                                 |
| Audit event emission                 | Emitting recovery lifecycle events to Chronicle | Must follow §8 event schema and NR-004.                                                                      |
| Abuse detection signals              | Rate limiting and suspicious request flagging   | Must not suppress or soft-fail these controls.                                                               |
| Post-recovery re-authentication flow | Directing user to sign-in after recovery        | Must not grant a session on completion of recovery.                                                          |

## What SIer Must NOT Implement Without ADR

| Prohibition                                                 | Reason                                                         |
| ----------------------------------------------------------- | -------------------------------------------------------------- |
| Email-only recovery (no operator approval)                  | Turns email compromise into full account takeover vector       |
| Bypass or shortening of 72h cooling period                  | P-009 invariant                                                |
| Any recovery that grants an authenticated session directly  | P-010 invariant                                                |
| Self-service recovery without operator involvement          | P-003 invariant — requires future ADR                          |
| Identity verification using only user-provided data         | Must use out-of-band verification                              |
| Recovery passcode changes that weaken entropy or algorithm  | DEC-005                                                        |
| Silent recovery (no user notification)                      | P-007 invariant                                                |
| MFA reset UI enablement without all 5 DEC-009 prerequisites | DEC-009                                                        |
| Operator approving their own MFA reset                      | Defined in `docs/security/mfa-reset-account-recovery.md`       |
| Catastrophic recovery path implementation                   | S-005 is OPEN BLOCKER. No path may be implemented without ADR. |

---

# 11. Security Vendor Scope

Security vendor SHOULD assess the following:

| Assessment Area              | What to Verify                                                                   |
| ---------------------------- | -------------------------------------------------------------------------------- |
| State machine completeness   | All transitions covered. Invalid transitions rejected.                           |
| Cooling period enforcement   | Request cannot be approved before 72h elapsed, regardless of operator action.    |
| Duplicate request prevention | Only one active request per account.                                             |
| Replay / stale request       | Expired or previously approved request cannot be replayed.                       |
| Unauthorized operator action | Approver cannot be the requestor. Second-operator bypass not possible.           |
| Audit evidence completeness  | All events in §8 are emitted. No secrets in audit records.                       |
| Session/token revocation     | All sessions and refresh families revoked atomically after recovery.             |
| Notification behavior        | All verified channels notified. No silent recovery.                              |
| Rejection path integrity     | Rejection leaves account completely unchanged.                                   |
| Abuse protection             | Rate limits, cooldowns, suspicious signal detection in place.                    |
| Identity verification        | Concrete steps defined and tested (OPEN BLOCKER at time of this draft).          |
| Catastrophic loss            | S-005 path either has a defined, audited procedure or is confirmed out of scope. |
| Recovery passcode rate limit | Confirmed gap (DEC-005). Assess current risk level.                              |
| Audit log immutability       | Confirmed gap (NR-004, GAP-002). Assess compensating controls.                   |

---

# 12. Acceptance Criteria

All acceptance criteria MUST be verified before MFA reset UI is enabled in production.

| ID          | Criterion                                                                                                             | Verification Method                                                          |
| ----------- | --------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| ACC-REC-001 | MFA reset UI remains disabled (`create` returns `reset_unavailable`) until all 5 DEC-009 prerequisites are signed off | Code review + test                                                           |
| ACC-REC-002 | Recovery request cannot be approved before 72h elapsed from request creation                                          | Integration test: attempt approval at t+71h → rejected                       |
| ACC-REC-003 | Operator cannot approve their own recovery request                                                                    | Integration test: operator submits own request, attempts approval → rejected |
| ACC-REC-004 | Successful recovery revokes all active sessions for the account                                                       | Test: verify all sessions invalidated; any active token returns 401          |
| ACC-REC-005 | Successful recovery revokes all refresh token families                                                                | Test: old refresh token returns error after recovery                         |
| ACC-REC-006 | Recovery does NOT grant an authenticated session                                                                      | Test: after recovery completion, user must sign in from scratch              |
| ACC-REC-007 | Rejection path leaves account completely unchanged                                                                    | Test: rejected recovery → verify all original credentials still valid        |
| ACC-REC-008 | All audit events in §8 are emitted for complete request lifecycle                                                     | Audit event log review for each test scenario                                |
| ACC-REC-009 | No secrets appear in any audit log record (passcodes, MFA secrets, tokens, cookies)                                   | Log review + automated scan for secret patterns                              |
| ACC-REC-010 | Duplicate request is blocked (only one active request per account)                                                    | Test: submit second request while first is active → rejected                 |
| ACC-REC-011 | Expired request cannot be approved                                                                                    | Test: expire request, attempt approval → rejected                            |
| ACC-REC-012 | Cancelled request stops cooling timer and leaves account unchanged                                                    | Test: cancel while session exists → account unchanged                        |
| ACC-REC-013 | All verified channels notified at request creation                                                                    | Test: verify notification dispatch for all registered channels               |
| ACC-REC-014 | Recovery passcode consumption is single-use                                                                           | Test: use same passcode twice → second attempt rejected                      |
| ACC-REC-015 | After recovery, user must complete MFA re-bootstrap before sensitive actions                                          | Test: attempt sensitive action without MFA → blocked                         |
| ACC-REC-016 | Abuse protection rate limits are enforced                                                                             | Test: exceed attempt rate → rate limit response, not error disclosure        |
| ACC-REC-017 | Identity verification outcome is recorded in audit                                                                    | Audit review: verification result in event log                               |
| ACC-REC-018 | State machine rejects invalid transitions                                                                             | Test: attempt arbitrary state jump → rejected with audit event               |
| ACC-REC-019 | Post-recovery monitoring window starts and operator is alerted if abuse signals appear                                | Integration test with mock abuse signal                                      |
| ACC-REC-020 | Recovery passcode rate limit is implemented (when remediated — DEC-005)                                               | Test: exceed attempt count → throttled or locked                             |

---

# 13. Open Questions and Blockers

| ID         | Item                                                                                                                                                                                     | Type                    | Status                                                                                          |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- | ----------------------------------------------------------------------------------------------- |
| **OQ-001** | **Identity verification concrete steps**: What specific methods are acceptable (government ID, video call, OTP to secondary contact, biometric)? What is the evidence recording format?  | **OPEN BLOCKER**        | Must be defined before MFA reset is deployed.                                                   |
| **OQ-002** | **Catastrophic account recovery (S-005)**: User has lost email + phone + all MFA + all passcodes. No defined resolution path exists.                                                     | **OPEN BLOCKER**        | Requires product + security + legal decision. ADR required before implementation.               |
| **OQ-003** | **Recovery passcode rate limit / lockout**: No rate limit or attempt lockout currently exists for recovery passcode verification (separate from MFA reset flow).                         | **KNOWN GAP**           | DEC-005. Remediation target. Specification required before implementation.                      |
| **OQ-004** | **Audit log DB-level immutability**: Chronicle does not have DB-level append-only constraints. Recovery audit events are among the highest-value targets for tampering.                  | **KNOWN GAP (BLOCKER)** | NR-004, GAP-002. Implementation method selection pending. Required before production MFA reset. |
| **OQ-005** | **Second-operator approval requirement**: Is second-operator review required for all MFA resets, or only for high-risk cases (org operators, admin accounts)?                            | OPEN                    | Policy decision pending.                                                                        |
| **OQ-006** | **Maximum request lifetime**: After how many days does an unapproved request expire automatically?                                                                                       | OPEN                    | Suggest 7 days; needs policy confirmation.                                                      |
| **OQ-007** | **Monitoring window duration**: How long is the post-recovery monitoring period, and what signals trigger escalation?                                                                    | OPEN                    | Needs SRE + security input.                                                                     |
| **OQ-008** | **GQ-06 Telephone-only AAL1**: Whether telephone OTP alone qualifies as AAL1 may affect which recovery paths are available when email is present but phone is the only remaining factor. | OPEN                    | Tracked separately (FACT-037).                                                                  |
| **OQ-009** | **Second-factor notification when no channels available**: If all registered notification channels are lost, can recovery be silently initiated? (Per P-007, no.) What is the fallback?  | OPEN                    | Part of catastrophic recovery (OQ-002).                                                         |
| **OQ-010** | **Recovery passcode re-issuance timing**: After MFA reset execution, when and how are new recovery passcodes issued? During re-bootstrap? Before?                                        | OPEN                    | Needs implementation design.                                                                    |

---

# 14. Relationship to Other Documents

| Document                                                 | Relationship                                                                           |
| -------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `docs/security/mfa-reset-account-recovery.md`            | Source of intended design. This document extends and operationalizes it.               |
| `docs/vendor/identity/01_responsibility_matrix.md`       | Defines Acme as session/token authority and MFA reset as BLOCKER in capability matrix. |
| `docs/vendor/identity/04_cookie-session-token-matrix.md` | Defines session/cookie revocation effects (§9 above).                                  |
| `docs/vendor/identity/13_normative-baseline.md`          | Defines MFA reset as DISABLED in §9. Recovery passcode gap in §9.                      |
| `docs/vendor/identity/08_threat-model.md`                | DRAFT. Account takeover via social engineering support is a relevant threat scenario.  |
| `docs/vendor/identity/09_acceptance-criteria.md`         | General acceptance criteria. Recovery-specific criteria in §12 above take precedence.  |
| `docs/vendor/identity/11_decision-register.md`           | Audit ledger. DEC-009 (MFA reset prerequisites), GAP-NEW-006/007, RSK-009, DEC-005.    |
