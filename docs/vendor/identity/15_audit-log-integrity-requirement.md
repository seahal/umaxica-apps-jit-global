---
title: Audit Log Integrity Requirement
status: rfi-draft
version: "2026-06-24-r4"
audience:
  - SIer
  - security-vendor
  - internal-architecture
  - operations
owner: internal-architecture-owner
last-reviewed: 2026-06-24
source-of-truth: current-repository-evidence
confidentiality: internal-vendor-shareable
related-audit-ledger: docs/vendor/identity/11_decision-register.md
---

# Purpose

Define the audit log integrity requirements for the identity/authentication/authorization
infrastructure. This document translates NR-004 into inspectable, testable requirements for SIer,
security-vendor, internal architecture, and operations.

This document is the normative reference for:

- critical audit event class definitions
- forbidden log data
- integrity threat scenarios
- implementation candidate comparison
- SIer and security-vendor scope for audit coverage

---

# ⚠ Critical Current State Warning

**Chronicle exists and records audit events. Critical audit event integrity is not yet guaranteed.**

| Capability                                            | Status              | Notes                                                                  |
| ----------------------------------------------------- | ------------------- | ---------------------------------------------------------------------- |
| Audit event recording system (Chronicle)              | **Implemented**     | Identity/auth events are recorded                                      |
| `event_uuid` UNIQUE index                             | **Implemented**     | Prevents duplicate insertion                                           |
| Retention policy classification                       | **Implemented**     | ephemeral / security / compliance / permanent                          |
| Application-level sanitization                        | **Implemented**     | FORBIDDEN_KEY_PATTERN, SENSITIVE_VALUE_PATTERNS filter tokens, secrets |
| `result` status states                                | **Implemented**     | intent → succeeded / failed / invalidated / manual_recovery_required   |
| DB-level immutability / append-only                   | **NOT IMPLEMENTED** | No trigger, restricted role, or constraint prevents UPDATE/DELETE      |
| Protection against DB admin mutation                  | **NOT IMPLEMENTED** | Chronicle rows can be modified or deleted at the DB layer              |
| Protection against application bug overwriting events | **NOT IMPLEMENTED** | Application can overwrite Chronicle rows                               |
| ChainSeal                                             | **Library only**    | future hardening candidate; NOT a production baseline                  |
| External immutable log sink                           | **NOT IMPLEMENTED** | No external sink replication                                           |

**This is a Procurement Blocker (GAP-002, DEC-013, NR-004).** The gap between "audit log exists" and
"critical audit event integrity is guaranteed" must be closed before RFP. The implementation method
has not yet been selected. See §8 for candidate comparison.

---

# 1. Document Status

| Field           | Value                                                                              |
| --------------- | ---------------------------------------------------------------------------------- |
| Status          | rfi-draft                                                                          |
| Owner           | internal-architecture-owner                                                        |
| Audience        | SIer, security-vendor, internal-architecture, operations                           |
| Confidentiality | internal-vendor-shareable                                                          |
| Last reviewed   | 2026-06-24 (Round 4 audit)                                                         |
| Related         | `docs/vendor/identity/11_decision-register.md` (DEC-013, NR-004, GAP-002, RSK-003) |

---

# 2. Scope

## In Scope

- identity / authentication / authorization / recovery / operator action / token lifecycle events
- SIer-implemented flow audit event emission requirements
- security-vendor audit integrity verification requirements
- integrity threat scenarios relevant to account compromise, insider abuse, and recovery disputes
- implementation candidate comparison and RFP-baseline recommendation

## Out of Scope

- Full SIEM procurement
- Legal retention final policy (pending legal review)
- ChainSeal production rollout implementation (future hardening)
- DB migration implementation (out of WRITE_ACCESS scope for this document)
- External storage vendor selection
- Non-identity application event logging

---

# 3. NR-004 — Normative Requirement (Verbatim)

```
Critical security audit events MUST be append-only at the application boundary.
Update/delete of critical audit events MUST be prevented or detectable.
Operator/admin access to audit records MUST be logged.
Audit event mutation, if technically possible, MUST leave independent evidence.
Token, cookie, OTP, passcode, private key, secret values MUST NOT be logged.
Audit retention and export policy MUST be documented.
```

**Source:** `docs/vendor/identity/11_decision-register.md` §3, DEC-013 (Round 3 audit, 2026-06-24)

NR-004 is a binding requirement. It is not advisory. Compliance is required before RFP and before
any SIer-implemented flow is accepted into production.

---

# 4. Protected Critical Audit Event Classes

The following event classes are classified as critical. They must satisfy the integrity requirements
in §3 (NR-004). Application-level sanitization alone is not sufficient.

Columns:

- **Actor** — who performed the action
- **Subject** — whose account or resource is affected
- **Resource** — the specific artifact changed
- **Result** — expected result states
- **Required Fields** — minimum fields per event record
- **Forbidden Fields** — fields that MUST NOT appear
- **Retention Class** — Chronicle retention tier
- **Integrity Requirement** — minimum integrity property
- **Alert Condition** — when to trigger operator or security alert
- **Acceptance Evidence** — how to verify the event is emitted correctly

---

## EC-001: Credential Created / Changed / Destroyed

| Field                 | Value                                                                                                                                       |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Actor                 | User (self), Operator (on behalf)                                                                                                           |
| Subject               | Account                                                                                                                                     |
| Resource              | Password-equivalent, passkey, TOTP secret                                                                                                   |
| Result                | succeeded / failed                                                                                                                          |
| Required Fields       | `actor_id`, `subject_account_id`, `credential_type`, `action` (created/changed/destroyed), `event_uuid`, `occurred_at`, `surface`, `result` |
| Forbidden Fields      | Credential value, secret bytes, private key, TOTP seed                                                                                      |
| Retention Class       | security                                                                                                                                    |
| Integrity Requirement | append-only; mutation MUST be prevented or detectable                                                                                       |
| Alert Condition       | Operator-initiated destruction; multiple destruction events in short window                                                                 |
| Acceptance Evidence   | Integration test: credential change emits event with correct fields; no secret in log                                                       |

---

## EC-002: MFA Enrolled / Removed / Reset

| Field                 | Value                                                                                           |
| --------------------- | ----------------------------------------------------------------------------------------------- |
| Actor                 | User (self), Operator (on behalf)                                                               |
| Subject               | Account                                                                                         |
| Resource              | Passkey, TOTP, recovery passcode stock                                                          |
| Result                | succeeded / failed                                                                              |
| Required Fields       | `actor_id`, `subject_account_id`, `mfa_method`, `action`, `event_uuid`, `occurred_at`, `result` |
| Forbidden Fields      | TOTP seed, passcode value, passkey private key                                                  |
| Retention Class       | security                                                                                        |
| Integrity Requirement | append-only; recovery events especially MUST NOT be mutable                                     |
| Alert Condition       | MFA reset on high-value account; multiple removals in short window                              |
| Acceptance Evidence   | Integration test: MFA reset emits all lifecycle events; no seed/value in log                    |

---

## EC-003: Social Identity Linked / Unlinked

| Field                 | Value                                                                                                                                          |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Actor                 | User (self), System (callback)                                                                                                                 |
| Subject               | Account                                                                                                                                        |
| Resource              | Social provider identity (provider + uid/sub)                                                                                                  |
| Result                | succeeded / failed / rejected                                                                                                                  |
| Required Fields       | `actor_id`, `subject_account_id`, `provider`, `uid_hash` (not raw uid), `action`, `email_verified_flag`, `event_uuid`, `occurred_at`, `result` |
| Forbidden Fields      | Raw uid/sub value, provider token, raw email if identifying                                                                                    |
| Retention Class       | security                                                                                                                                       |
| Integrity Requirement | append-only; linking disputes require tamper-evident records                                                                                   |
| Alert Condition       | Linking of uid already linked to another account; `email_verified=false` rejection                                                             |
| Acceptance Evidence   | NR-001 social linking test includes audit event verification                                                                                   |

---

## EC-004: Token Issued / Refreshed / Revoked

| Field                 | Value                                                                                                                                                    |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Actor                 | System, User (revocation), Operator (forced revocation)                                                                                                  |
| Subject               | Account                                                                                                                                                  |
| Resource              | Authorization code, access token, refresh token, ID token                                                                                                |
| Result                | issued / refreshed / revoked / replay_detected                                                                                                           |
| Required Fields       | `actor_id`, `subject_account_id`, `token_type`, `action`, `jti` (not value), `family_id` (for refresh), `event_uuid`, `occurred_at`, `result`, `surface` |
| Forbidden Fields      | Access token value, refresh token value, ID token value, authorization code value                                                                        |
| Retention Class       | security                                                                                                                                                 |
| Integrity Requirement | append-only; refresh family audit chain must be reconstructable                                                                                          |
| Alert Condition       | Replay detected; family-wide revocation; token revocation by operator                                                                                    |
| Acceptance Evidence   | Token endpoint test: issuance event emitted; revocation emits event; no token value in log                                                               |

---

## EC-005: Session Created / Limited / Revoked

| Field                 | Value                                                                                                                               |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Actor                 | User, System, Operator                                                                                                              |
| Subject               | Account                                                                                                                             |
| Resource              | Session (surface-specific)                                                                                                          |
| Result                | created / limited / revoked                                                                                                         |
| Required Fields       | `actor_id`, `subject_account_id`, `session_id` (non-identifying handle), `surface`, `action`, `event_uuid`, `occurred_at`, `result` |
| Forbidden Fields      | Session cookie value, auth cookie value                                                                                             |
| Retention Class       | security                                                                                                                            |
| Integrity Requirement | append-only; session limit enforcement must be auditable                                                                            |
| Alert Condition       | Forced revocation by operator; session limit exceeded                                                                               |
| Acceptance Evidence   | Session lifecycle test: create/limit/revoke events emitted with correct surface                                                     |

---

## EC-006: Passkey Registered / Removed

| Field                 | Value                                                                                                   |
| --------------------- | ------------------------------------------------------------------------------------------------------- |
| Actor                 | User (self)                                                                                             |
| Subject               | Account                                                                                                 |
| Resource              | WebAuthn credential                                                                                     |
| Result                | registered / removed                                                                                    |
| Required Fields       | `actor_id`, `subject_account_id`, `credential_id_hash`, `action`, `event_uuid`, `occurred_at`, `result` |
| Forbidden Fields      | Passkey private key, raw credential material, WebAuthn challenge secret                                 |
| Retention Class       | security                                                                                                |
| Integrity Requirement | append-only                                                                                             |
| Alert Condition       | All passkeys removed; passkey added from new device                                                     |
| Acceptance Evidence   | Passkey controller test includes audit event assertion                                                  |

---

## EC-007: Recovery Passcode Generated / Revealed / Consumed

| Field                 | Value                                                                             |
| --------------------- | --------------------------------------------------------------------------------- |
| Actor                 | System (generation), User (reveal/consume)                                        |
| Subject               | Account                                                                           |
| Resource              | Recovery passcode                                                                 |
| Result                | generated / revealed / consumed / failed                                          |
| Required Fields       | `actor_id`, `subject_account_id`, `action`, `event_uuid`, `occurred_at`, `result` |
| Forbidden Fields      | Passcode plaintext, passcode digest                                               |
| Retention Class       | security                                                                          |
| Integrity Requirement | append-only; consumed record MUST NOT be deletable                                |
| Alert Condition       | Rapid consumption of multiple passcodes; consumption from unusual IP              |
| Acceptance Evidence   | Recovery passcode test: each lifecycle action emits event; no value in log        |

---

## EC-008: Account Recovery Requested / Approved / Rejected / Executed

| Field                 | Value                                                                                                                             |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Actor                 | User (request/cancel), Operator (approve/reject)                                                                                  |
| Subject               | Account                                                                                                                           |
| Resource              | MFA reset request                                                                                                                 |
| Result                | requested / approved / rejected / executed / expired / cancelled                                                                  |
| Required Fields       | `actor_id`, `subject_account_id`, `operator_id` (where applicable), `action`, `event_uuid`, `occurred_at`, `result`, `request_id` |
| Forbidden Fields      | Identity verification document content, passcode, MFA secret                                                                      |
| Retention Class       | compliance                                                                                                                        |
| Integrity Requirement | append-only; entire recovery chain MUST be reconstructable; HIGHEST PRIORITY integrity target                                     |
| Alert Condition       | Any approval; execution; rejection after prior approval                                                                           |
| Acceptance Evidence   | Recovery lifecycle test: all state transitions emit events; chain is reconstructable in test                                      |

---

## EC-009: Operator Action on User Account

| Field                 | Value                                                                                           |
| --------------------- | ----------------------------------------------------------------------------------------------- |
| Actor                 | Operator                                                                                        |
| Subject               | Account                                                                                         |
| Resource              | Any user account mutation                                                                       |
| Result                | succeeded / failed                                                                              |
| Required Fields       | `operator_id`, `subject_account_id`, `action_type`, `event_uuid`, `occurred_at`, `result`       |
| Forbidden Fields      | Any credential value                                                                            |
| Retention Class       | security                                                                                        |
| Integrity Requirement | append-only; operator access to audit records must itself be logged (NR-004)                    |
| Alert Condition       | Any operator access to audit log; high volume of operator account mutations                     |
| Acceptance Evidence   | Operator controller test includes audit event assertion; operator audit access is itself logged |

---

## EC-010: Privilege Change

| Field                 | Value                                                                                               |
| --------------------- | --------------------------------------------------------------------------------------------------- |
| Actor                 | Operator, System                                                                                    |
| Subject               | Account                                                                                             |
| Resource              | Role, permission, surface access                                                                    |
| Result                | granted / revoked                                                                                   |
| Required Fields       | `actor_id`, `subject_account_id`, `privilege_type`, `action`, `event_uuid`, `occurred_at`, `result` |
| Forbidden Fields      | —                                                                                                   |
| Retention Class       | security                                                                                            |
| Integrity Requirement | append-only                                                                                         |
| Alert Condition       | Privilege grant on operator account; grant followed by audit access                                 |
| Acceptance Evidence   | Privilege change test includes audit event assertion                                                |

---

## EC-011: Authorization Denial for Sensitive Action

| Field                 | Value                                                                                                  |
| --------------------- | ------------------------------------------------------------------------------------------------------ |
| Actor                 | User, Operator                                                                                         |
| Subject               | Resource being accessed                                                                                |
| Resource              | Sensitive action endpoint                                                                              |
| Result                | denied                                                                                                 |
| Required Fields       | `actor_id`, `subject_account_id`, `action_type`, `policy_class`, `event_uuid`, `occurred_at`, `result` |
| Forbidden Fields      | Request params, cookie, token                                                                          |
| Retention Class       | security                                                                                               |
| Integrity Requirement | append-only                                                                                            |
| Alert Condition       | Repeated denials from same actor; denial following recent privilege change                             |
| Acceptance Evidence   | Policy test: denial emits event; repeated denial triggers alert threshold                              |

---

## EC-012: Suspicious Recovery Request

| Field                 | Value                                                                                  |
| --------------------- | -------------------------------------------------------------------------------------- |
| Actor                 | System (detection), Operator                                                           |
| Subject               | Account                                                                                |
| Resource              | Recovery request                                                                       |
| Result                | flagged / locked                                                                       |
| Required Fields       | `actor_id`, `subject_account_id`, `signal_type`, `event_uuid`, `occurred_at`, `result` |
| Forbidden Fields      | Raw signal payload if containing PII beyond threshold                                  |
| Retention Class       | security                                                                               |
| Integrity Requirement | append-only                                                                            |
| Alert Condition       | Every occurrence                                                                       |
| Acceptance Evidence   | Abuse detection test: suspicious signal emits event; account lock emits event          |

---

## EC-013: Key Rotation

| Field                 | Value                                                                                      |
| --------------------- | ------------------------------------------------------------------------------------------ |
| Actor                 | System, Operations                                                                         |
| Subject               | Signing key                                                                                |
| Resource              | JWT signing key, WebAuthn RP key                                                           |
| Result                | rotated / failed                                                                           |
| Required Fields       | `actor_id`, `key_id_new`, `key_id_old`, `algorithm`, `event_uuid`, `occurred_at`, `result` |
| Forbidden Fields      | Private key material                                                                       |
| Retention Class       | compliance                                                                                 |
| Integrity Requirement | append-only                                                                                |
| Alert Condition       | Every occurrence                                                                           |
| Acceptance Evidence   | Key rotation test emits event; no private key in log                                       |

---

## EC-014: Audit Configuration Change

| Field                 | Value                                                                                            |
| --------------------- | ------------------------------------------------------------------------------------------------ |
| Actor                 | Operations, DB admin                                                                             |
| Subject               | Chronicle configuration                                                                          |
| Resource              | Retention policy, sanitization rules, event class definitions                                    |
| Result                | changed                                                                                          |
| Required Fields       | `actor_id`, `config_key`, `previous_value_class`, `new_value_class`, `event_uuid`, `occurred_at` |
| Forbidden Fields      | —                                                                                                |
| Retention Class       | compliance                                                                                       |
| Integrity Requirement | append-only; this event class is self-referential — it MUST NOT be suppressible                  |
| Alert Condition       | Every occurrence                                                                                 |
| Acceptance Evidence   | Configuration change test emits event                                                            |

---

## EC-015: Incident Response Action

| Field                 | Value                                                                                            |
| --------------------- | ------------------------------------------------------------------------------------------------ |
| Actor                 | Operations, Security team                                                                        |
| Subject               | Account or system                                                                                |
| Resource              | Any resource under incident investigation                                                        |
| Result                | initiated / resolved / escalated                                                                 |
| Required Fields       | `actor_id`, `incident_id`, `action_type`, `subject_scope`, `event_uuid`, `occurred_at`, `result` |
| Forbidden Fields      | Raw request payload, credential values                                                           |
| Retention Class       | compliance                                                                                       |
| Integrity Requirement | append-only                                                                                      |
| Alert Condition       | Every occurrence                                                                                 |
| Acceptance Evidence   | Incident response runbook test includes audit event                                              |

---

# 5. Forbidden Log Data

The following values MUST NEVER appear in any Chronicle audit event, application log, error log, or
debug output — in plaintext, encoded, or partial form.

| Forbidden Category              | Examples                          |
| ------------------------------- | --------------------------------- |
| Access token value              | `Bearer eyJ...`                   |
| Refresh token value             | Any refresh token string          |
| ID token value                  | Any `id_token` string             |
| Cookie value                    | `__Host-auth=...`, `_session=...` |
| OTP / TOTP value                | 6-digit code, TOTP seed           |
| Recovery passcode value         | base58 passcode                   |
| WebAuthn challenge secret       | Raw challenge bytes               |
| Private key material            | Any PEM or raw private key        |
| Client secret                   | OAuth client secret               |
| Provider token                  | Google/Apple access or ID token   |
| Raw authorization code          | Short-lived code value            |
| Password or password-equivalent | Any password hash input           |
| Full credential material        | Any concatenation of the above    |

## Permitted Identifiers (Allowed in Logs)

The following identifiers are safe to log. They identify events without disclosing secret values.

| Identifier           | Description                                           | Format        |
| -------------------- | ----------------------------------------------------- | ------------- |
| `event_uuid`         | Chronicle event identifier                            | UUID v4       |
| `jti`                | JWT ID claim                                          | Opaque string |
| `family_id`          | Refresh token family identifier                       | Opaque hash   |
| `credential_type`    | Type label only (`passkey`, `totp`, `passcode`)       | Enum string   |
| `token_type`         | Token class label (`access`, `refresh`, `id`, `code`) | Enum string   |
| `credential_id_hash` | Hash of WebAuthn credential_id                        | SHA-256 hex   |
| `uid_hash`           | Hash of social provider uid                           | SHA-256 hex   |
| `key_id`             | JWT `kid` header value                                | Opaque string |
| `session_handle`     | Non-sensitive session reference                       | Opaque string |
| `request_id`         | Recovery or workflow request identifier               | UUID v4       |
| `actor_id`           | Internal account UUID                                 | UUID          |
| `operator_id`        | Internal operator UUID                                | UUID          |

---

# 6. Integrity Threat Scenarios

## TS-001: Compromised Operator Deletes Recovery Evidence

| Field                       | Value                                                                                                       |
| --------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Scenario                    | A compromised operator account deletes or modifies Chronicle rows for a recovery request after the fact.    |
| Impact                      | The recovery audit chain is unrecoverable. Account takeover via social engineering cannot be reconstructed. |
| Current Control             | `event_uuid` UNIQUE prevents duplicate; application sanitization prevents secrets                           |
| Missing Control             | No DB-level append-only; operator with DB access can DELETE or UPDATE rows                                  |
| Required Integrity Property | DB-level immutability OR tamper-evident hash chain                                                          |
| Detection Method            | Hash chain mismatch; external sink divergence; audit configuration change event                             |
| Response Owner              | Security team                                                                                               |

## TS-002: SIer-Implemented Flow Emits No Audit Event

| Field                       | Value                                                                                                                   |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Scenario                    | A SIer-implemented credential change or social linking flow reaches production without emitting Chronicle events.       |
| Impact                      | Critical account mutations are invisible. Security review, incident investigation, and compliance reporting are broken. |
| Current Control             | Chronicle exists; some events are emitted by existing flows                                                             |
| Missing Control             | No mandatory acceptance gate requiring audit event tests before SIer flow is accepted                                   |
| Required Integrity Property | Pre-acceptance audit coverage verification (ACC-AUD-010)                                                                |
| Detection Method            | Security-vendor audit coverage check; CI test for event emission                                                        |
| Response Owner              | Internal architecture owner; SIer (responsible for providing tests)                                                     |

## TS-003: Account Takeover via Recovery; Audit Log Later Modified

| Field                       | Value                                                                                                                                            |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Scenario                    | An attacker uses social engineering to trigger MFA reset. After gaining access, they modify the Chronicle rows that record the recovery request. |
| Impact                      | Forensic reconstruction of the attack is impossible. Operator culpability cannot be established.                                                 |
| Current Control             | Recovery requires 72h cooling + operator approval                                                                                                |
| Missing Control             | No DB-level immutability for recovery event chain                                                                                                |
| Required Integrity Property | append-only for EC-008; entire chain must be reconstructable after the fact                                                                      |
| Detection Method            | External sink divergence; hash chain audit                                                                                                       |
| Response Owner              | Security team; internal architecture owner                                                                                                       |

## TS-004: Refresh Token Family Abuse Cannot Be Reconstructed

| Field                       | Value                                                                                                                                                                                                        |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Scenario                    | Replay attack on a refresh token. The attacker uses the original token after the victim rotated. Family revocation is triggered. Post-incident review needs to reconstruct which tokens were valid and when. |
| Impact                      | Cannot determine scope of compromise. Cannot distinguish legitimate from attacker sessions.                                                                                                                  |
| Current Control             | `family_id` exists; rotation records exist                                                                                                                                                                   |
| Missing Control             | No guarantee that audit rows recording the family history have not been altered                                                                                                                              |
| Required Integrity Property | append-only for EC-004 refresh events; `family_id` chain must be queryable                                                                                                                                   |
| Detection Method            | Hash chain or external sink comparison                                                                                                                                                                       |
| Response Owner              | Operations                                                                                                                                                                                                   |

## TS-005: Social Account Linking Dispute

| Field                       | Value                                                                                                         |
| --------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Scenario                    | A user claims they never linked a social account to their account. Provider claims the callback was received. |
| Impact                      | Without an immutable linking event, neither the user nor the platform can prove what happened.                |
| Current Control             | EC-003 social linking event is defined                                                                        |
| Missing Control             | Linking event is mutable at DB level                                                                          |
| Required Integrity Property | append-only for EC-003; `provider` + `uid_hash` must be recorded at link time                                 |
| Detection Method            | External sink comparison                                                                                      |
| Response Owner              | Operations; security vendor on request                                                                        |

## TS-006: Privilege Escalation Followed by Log Deletion

| Field                       | Value                                                                                                                                                                 |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Scenario                    | An internal actor grants themselves elevated privilege (EC-010), performs unauthorized actions, then deletes or modifies the Chronicle rows recording the escalation. |
| Impact                      | Privilege abuse is undetectable. Regulatory exposure without audit trail.                                                                                             |
| Current Control             | Privilege change is classified as critical event class (EC-010)                                                                                                       |
| Missing Control             | No DB-level protection prevents deletion after privilege escalation                                                                                                   |
| Required Integrity Property | append-only for EC-010; EC-009 (operator action) also append-only                                                                                                     |
| Detection Method            | External sink; hash chain; alert on audit config change (EC-014)                                                                                                      |
| Response Owner              | Security team                                                                                                                                                         |

## TS-007: Database Administrator Modifies Audit Rows

| Field                       | Value                                                                                                                                   |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Scenario                    | A database administrator uses privileged DB access to alter Chronicle event records — either to cover tracks or to frame another actor. |
| Impact                      | Audit records are untrusted. Forensic investigation is unreliable.                                                                      |
| Current Control             | None                                                                                                                                    |
| Missing Control             | DB-level append-only OR external immutable sink that DB admin cannot access                                                             |
| Required Integrity Property | Independent verification path (external sink or cryptographic seal) not accessible to DB admin                                          |
| Detection Method            | External sink divergence; periodic hash digest mismatch                                                                                 |
| Response Owner              | Internal architecture owner; security vendor                                                                                            |

## TS-008: Application Bug Overwrites Audit Event

| Field                       | Value                                                                                                                                        |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Scenario                    | An application-level bug (race condition, misconfigured update path) calls UPDATE on a Chronicle row, silently replacing correct audit data. |
| Impact                      | Silent data corruption of audit record. No indication to operators.                                                                          |
| Current Control             | Application sanitization prevents certain field writes                                                                                       |
| Missing Control             | No DB-level constraint prevents UPDATE to Chronicle table                                                                                    |
| Required Integrity Property | DB trigger or restricted role blocking any UPDATE to audit rows                                                                              |
| Detection Method            | Periodic hash chain validation; DB audit log for UPDATE operations                                                                           |
| Response Owner              | Internal architecture owner                                                                                                                  |

## TS-009: External Incident Response Needs Reliable Timeline

| Field                       | Value                                                                                                                                                            |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Scenario                    | An external security vendor or regulator requests a reliable, tamper-evident timeline of authentication events for a specific account during an incident window. |
| Impact                      | Without tamper-evidence, the timeline cannot be presented as reliable. Incident response is degraded. Potential regulatory exposure.                             |
| Current Control             | Chronicle provides a timeline; `event_uuid` and `occurred_at` exist                                                                                              |
| Missing Control             | No tamper-evidence property; no export verification mechanism                                                                                                    |
| Required Integrity Property | Export must be verifiable; records must carry tamper-evidence marker or external sync hash                                                                       |
| Detection Method            | Export hash comparison                                                                                                                                           |
| Response Owner              | Operations; security vendor                                                                                                                                      |

---

# 7. Implementation Candidate Comparison

The following candidates are evaluated as approaches to satisfying NR-004. This comparison is
informational. The implementation method has not been selected. See §9 for provisional
recommendation.

| Property                             | A: DB Trigger (block UPDATE/DELETE) | B: Separate Append-Only Table  | C: Restricted DB Role               | D: Hash Chain / Periodic Digest | E: External Log Sink             | F: ChainSeal Production | G: Combination (A+C+E)     |
| ------------------------------------ | ----------------------------------- | ------------------------------ | ----------------------------------- | ------------------------------- | -------------------------------- | ----------------------- | -------------------------- |
| **Prevents mutation**                | Yes (at DB layer)                   | Yes (insert-only schema)       | Partial (depends on role isolation) | No (detects, not prevents)      | No (detects divergence)          | Yes (cryptographic)     | Yes                        |
| **Detects mutation**                 | Partial (may suppress trigger)      | Partial (if monitored)         | Partial                             | Yes                             | Yes                              | Yes                     | Yes                        |
| **Protects vs app bug**              | Yes                                 | Yes                            | Partial                             | No                              | Yes (post-fact)                  | Yes                     | Yes                        |
| **Protects vs compromised app role** | Yes                                 | Yes                            | Yes (if separate role)              | No                              | Yes (post-fact)                  | Yes                     | Yes                        |
| **Protects vs DB admin**             | No (admin can disable trigger)      | No (admin can drop constraint) | No (admin can grant role)           | Partial (detects if external)   | Yes (if admin cannot reach sink) | Yes                     | Yes (with external E)      |
| **Operational complexity**           | Low                                 | Medium                         | Low                                 | Medium                          | Medium-High                      | High                    | High                       |
| **Migration risk**                   | Low                                 | Medium                         | Low                                 | Low                             | Medium                           | High                    | Medium                     |
| **Testability**                      | High                                | High                           | High                                | Medium                          | Medium                           | Medium                  | Medium                     |
| **Rollback impact**                  | Low                                 | Medium                         | Low                                 | Low                             | Low                              | High                    | Medium                     |
| **Suitability: RFI**                 | Sufficient as stated gap            | Sufficient as stated gap       | Sufficient as stated gap            | Sufficient as stated gap        | Sufficient as stated gap         | Out of scope            | N/A                        |
| **Suitability: RFP**                 | Yes — short-term baseline           | Yes — short-term baseline      | Yes — required regardless           | As supplement                   | As supplement                    | Not required for RFP    | Yes — recommended baseline |
| **Suitability: Production**          | Required                            | Recommended                    | Required                            | Recommended                     | Recommended                      | Long-term hardening     | Recommended                |
| **Recommended status**               | **Required (short-term)**           | **Recommended (medium-term)**  | **Required (short-term)**           | Supplement                      | Supplement                       | Future hardening        | **Provisional baseline**   |

**Key finding:** No single candidate fully protects against a DB administrator with superuser
access. Only E (external log sink) or F (ChainSeal) provides independent evidence outside the DB
admin's reach. For RFP baseline, A+C is the minimum viable requirement. E is the recommended
medium-term addition.

---

# 8. Recommended Baseline

## Short-term RFP Baseline (required before RFP)

- Fix the critical event classes defined in §4 (EC-001〜EC-015)
- Application boundary contract: Chronicle rows MUST NOT be updated or deleted by any
  application-layer path
- DB-level: deploy trigger (Candidate A) blocking UPDATE/DELETE on Chronicle critical event tables,
  OR migrate to separate append-only table (Candidate B)
- DB role restriction (Candidate C): application DB role MUST NOT have DELETE privilege on Chronicle
  tables
- SIer-implemented flows MUST emit Chronicle audit events per §4 schema
- Secrets logging prohibition (§5 Forbidden) MUST be enforced via sanitization rules and test
  coverage

## Medium-term Production Baseline (before production MFA reset deployment)

- DB-level append-only or tamper-evidence in place (A or B)
- Restricted application DB role (C) in place
- Operator access to audit records is itself logged (NR-004)
- Audit mutation detection: periodic hash chain or external sink replication (D or E)
- Restore and export verification: export must be verifiable; `event_uuid` ordering preserved
- Chronicle immutability remediation status: closed (GAP-002 resolved)

## Long-term Hardening

- ChainSeal production deployment (Candidate F) or equivalent cryptographic sealing
- External immutable storage / independent sink not accessible to application DB admin
- Periodic automated digest verification
- Incident response export carries tamper-evidence marker

---

# 9. SIer Scope

## What SIer May Do

| Capability                                                 | Constraint                                                                    |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Emit new Chronicle audit events for SIer-implemented flows | Must follow event schema defined in §4; must not log forbidden values from §5 |
| Add new event types to Chronicle (if genuinely new class)  | Must not reuse existing event_type strings with different semantics           |
| Write audit event emission tests                           | Required — SIer flow cannot be accepted without audit coverage (ACC-AUD-010)  |
| Read Chronicle schema for event structure                  | Read-only reference; no schema changes                                        |

## What SIer Must NOT Do

| Prohibition                                                          | Reason                                                                               |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Change Chronicle schema, retention policy, or sanitization rules     | Requires ADR and internal architecture approval                                      |
| Mark audit integrity blocker as resolved (GAP-002)                   | Resolution requires internal architecture owner sign-off, not SIer unilateral action |
| Implement ad-hoc logging outside Chronicle for critical events       | Splits audit trail; creates orphaned records that bypass integrity controls          |
| Log any secret, token, OTP, cookie, or credential value              | NR-004 absolute prohibition                                                          |
| Emit audit events with inconsistent schema (missing required fields) | Breaks incident reconstruction and acceptance tests                                  |
| Bypass or suppress Chronicle sanitization rules                      | Application-level defense; must not be degraded                                      |
| Implement DB-level integrity controls unilaterally                   | DB migration for integrity requires ADR and internal review                          |

---

# 10. Security Vendor Scope

Security vendor SHOULD assess and report on all of the following:

| Assessment Area            | What to Verify                                                                                          |
| -------------------------- | ------------------------------------------------------------------------------------------------------- |
| Critical event coverage    | All EC-001〜EC-015 classes are emitted for their corresponding flows                                    |
| Forbidden value absence    | No token, cookie, OTP, passcode, or key value appears in Chronicle records (sample + automated scan)    |
| Required field presence    | `actor_id`, `subject_account_id`, `event_uuid`, `occurred_at`, `result` present on every critical event |
| Recovery event chain       | EC-008 chain (requested → cooling → approved → executed) is fully reconstructable from Chronicle        |
| Token family chain         | EC-004 refresh family events are reconstructable by `family_id`                                         |
| Operator action logging    | EC-009 is emitted for every operator mutation on a user account                                         |
| Audit access logging       | Operator access to Chronicle records is itself logged (NR-004)                                          |
| DB-level immutability      | Attempt UPDATE/DELETE on Chronicle tables in test environment; confirm result                           |
| Integrity candidate design | Review and report on selected candidate from §7; confirm NR-004 coverage                                |
| Export verification        | Audit export preserves `event_uuid`, `occurred_at` ordering; hash or signature verifiable               |
| Residual risk report       | After assessment, report residual risks not covered by selected candidate                               |

---

# 11. Acceptance Criteria

All criteria MUST be verified before production deployment of any SIer-implemented flow that touches
critical audit event classes. ACC-AUD-001〜005 additionally apply to current baseline.

| ID          | Criterion                                                                                                | Verification Method                                                                         |
| ----------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| ACC-AUD-001 | All EC-001〜EC-015 event classes emit Chronicle events for their triggers                                | Integration test per event class                                                            |
| ACC-AUD-002 | No forbidden value (token, cookie, OTP, passcode, key) appears in any Chronicle event                    | Automated log scan + security vendor spot check                                             |
| ACC-AUD-003 | Every critical event has `actor_id`, `subject_account_id`, `event_uuid`, `occurred_at`, `result`         | Schema validation test                                                                      |
| ACC-AUD-004 | Operator action on any user account emits EC-009                                                         | Integration test: operator mutation → event in Chronicle                                    |
| ACC-AUD-005 | Operator access to Chronicle audit records is itself logged                                              | Integration test: Chronicle query by operator → access event                                |
| ACC-AUD-006 | Recovery event chain (EC-008) is fully reconstructable from Chronicle for a complete MFA reset lifecycle | Integration test: complete lifecycle → query Chronicle → reconstruct chain                  |
| ACC-AUD-007 | Refresh token family chain (EC-004) is reconstructable by `family_id`                                    | Integration test: issue, rotate, revoke → query by family_id                                |
| ACC-AUD-008 | Chronicle rows cannot be updated or deleted via application layer                                        | Test: direct application call attempting UPDATE/DELETE on Chronicle row → rejected or no-op |
| ACC-AUD-009 | Chronicle rows cannot be updated or deleted at DB layer by application role                              | DB privilege test: application role does not have DELETE on Chronicle tables                |
| ACC-AUD-010 | No SIer-implemented flow is accepted without audit event integration tests                               | Pre-acceptance review checklist; automated CI gate                                          |
| ACC-AUD-011 | Audit export preserves `event_uuid` and `occurred_at` ordering                                           | Export test: compare Chronicle query vs export order and identifiers                        |
| ACC-AUD-012 | DB-level immutability implementation is in place and verified (when remediated)                          | Security vendor: attempt UPDATE/DELETE in test environment → confirm blocked                |
| ACC-AUD-013 | Chronicle sanitization rules block all forbidden key patterns in test                                    | Unit test: inject forbidden keys → verify stripped from event                               |
| ACC-AUD-014 | Audit configuration change (EC-014) emits event                                                          | Integration test: change sanitization rule → EC-014 emitted                                 |
| ACC-AUD-015 | Security vendor can enumerate critical event coverage from test environment                              | Security vendor acceptance: produce coverage map; compare to §4                             |

---

# 12. Open Questions and Blockers

| ID             | Item                                                                                                                                  | Type             | Status                                                                                       |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | -------------------------------------------------------------------------------------------- |
| **OQ-AUD-001** | **DB-level immutability implementation method**: trigger (A), append-only table (B), or combination — not yet selected                | **OPEN BLOCKER** | Must be selected before RFP                                                                  |
| **OQ-AUD-002** | **ChainSeal production timeline**: no date or prerequisite list defined                                                               | OPEN             | Long-term hardening; not required for RFP                                                    |
| **OQ-AUD-003** | **External log sink vendor**: no vendor selected; no evaluation criteria defined                                                      | OPEN             | Recommended for medium-term; not blocking RFP baseline                                       |
| **OQ-AUD-004** | **Legal retention final policy**: retention classes (ephemeral/security/compliance/permanent) exist but legal review is not complete  | OPEN             | Required before production; not blocking RFP                                                 |
| **OQ-AUD-005** | **Who may access Chronicle operationally**: operational access policy for audit records is not documented                             | OPEN             | Required before production; NR-004 requires operator access to be logged                     |
| **OQ-AUD-006** | **DB admin mutation risk**: no independent evidence path (external sink or ChainSeal) currently exists that is outside DB admin reach | **KNOWN GAP**    | Residual risk until E or F implemented                                                       |
| **OQ-AUD-007** | **Scope of integrity requirement**: does NR-004 apply to all Chronicle events, or only critical event classes (EC-001〜EC-015)?       | OPEN             | Suggest: all events use append-only; critical classes additionally use external sink or seal |

---

# 13. Relationship to Other Documents

| Document                                                 | Relationship                                                                                                                                    |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `docs/vendor/identity/01_responsibility_matrix.md`       | §H: SIer audit event emission scope. Section G: Chronicle audit responsibility (Acme OWN, SIer IMPL for new flows, TEST/EVIDENCE for coverage)  |
| `docs/vendor/identity/04_cookie-session-token-matrix.md` | §9 (NR-004 Audit Event Binding): 17 event types bound to specific artifacts. This document expands those into full event class definitions      |
| `docs/vendor/identity/13_normative-baseline.md`          | §11: Audit/logging baseline. This document is the detailed expansion                                                                            |
| `docs/vendor/identity/14_account-recovery-procedure.md`  | §8: Audit requirements for recovery lifecycle. This document is the system-wide integrity authority                                             |
| `docs/vendor/identity/08_threat-model.md`                | Threat model contains audit-relevant scenarios. This document's §6 (Integrity Threat Scenarios) is the identity-audit-specific subset           |
| `docs/vendor/identity/11_decision-register.md`           | DEC-013 (Audit log integrity = required), NR-004 (verbatim requirement), GAP-002 (Chronicle immutability absent), RSK-003 (risk register entry) |
