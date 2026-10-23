# ADR: Authentication Security Mode

**Status:** Accepted (2026-10-15). Recorded from the WU-2 design dialogue. Not implemented; the
current code still uses `mfa_level_id` and the `NOTHING/WEAK/MEDIUM/FULL` reference values.

> **Partial supersession (2026-10-15):** `adr/authentication-security-cycle-consolidation-2026-10-15.md` supersedes A4 and E1 (the
> `ADVANCED` minimum is two active passkeys, not one), E2 (two to one is refused), the clause of C3
> that Emergency never satisfies Persona/RP authorization, F1–F5 and G2 (returned to Pending), and
> resolves Open decision 2. Those sections are kept below as history and are not current.
>
> **Open decision 1 (2026-10-23):** answered by the consolidation ADR §2.2 — the `ADVANCED` minimum is
> two active passkeys and nothing else counts. Value mapping for the migration (D-92): APP/COM every
> value → `NORMAL=3`; ORG every Operator → `ADVANCED=7`.

## Context

Each actor's sign-in and step-up strength is currently described by `mfa_level_id` (`NOTHING=0`,
`WEAK=1`, `MEDIUM=5`, `FULL=9`) and a legacy `mfa_level_enabled` flag. The values do not name the
policy they select, `NOTHING` doubles as a default, and the column is not tied to step-up method
sets, passkey lifecycle rules or recovery behavior. WU-2 replaces it with an explicit, owner-held
Security Mode that drives those rules.

## Decision

### A. Naming and values

- **A1.** `mfa_level_id` is renamed to `security_mode_id`. The reference models and associations
  are renamed with it.
- **A2.** The current modes are `NORMAL = 3` and `ADVANCED = 7`. The names `MEDIUM`, `WEAK`,
  `FULL` and `STRICT` are retired.
- **A3.** `NOTHING = 0` is not a valid authentication mode.
- **A4.** The minimum active passkey count is defined by mode ID: IDs `1..6` allow zero, ID `7`
  requires at least one. This rule exists for future extension only; IDs `1`, `2`, `4`, `5` and `6`
  are not valid modes now.
- **A5.** Unknown mode values fail closed.

### B. Mode by surface

- **B1.** APP and COM sign-up starts in `NORMAL`. The owner may move to `ADVANCED` by their own
  action. Sign-up never forces `ADVANCED`.
- **B2.** ORG is always `ADVANCED`.
- **B3.** The Identity belongs to its owner. No third-party Operator may downgrade an Identity's
  Security Mode.

### C. Sign-in

- **C1.** APP/COM `ADVANCED` ordinary sign-in requires a passkey. APP social sign-in also requires
  passkey confirmation in `ADVANCED`.
- **C2.** ORG ordinary sign-in remains Entra ID followed by passkey.
- **C3.** ORG Emergency is a restricted authentication context, not ordinary access. It is distinct
  from ordinary sessions and recovery sessions, and it never satisfies ordinary step-up or Persona/RP
  authorization.

### D. Step-up

- **D1.** Method sets:

  | mode       | APP                          | COM                   | ORG          |
  | ---------- | ---------------------------- | --------------------- | ------------ |
  | `NORMAL`   | Email OTP / Passkey / TOTP   | Email OTP / Passkey   | not used     |
  | `ADVANCED` | Passkey                      | Passkey               | Passkey      |

- **D2.** Maximum step-up validity is 15 minutes in `NORMAL` and 5 minutes in `ADVANCED`.
- **D3.** Step-up evidence is bound to the operation, the target, the actor and the session, and is
  consumed once. The previous scope-level reuse within 15 minutes is replaced.

### E. Passkey credential lifecycle

- **E1.** In `ADVANCED`, at least one active passkey remains. Deleting the last one is refused.
- **E2.** With passkeys P1 and P2, deleting P1 may be re-authenticated with P2 or with P1 itself.
  The post-deletion minimum and the step-up requirement are checked separately.
- **E3.** In `NORMAL`, an owner whose only method is Email OTP may register a first passkey after a
  purpose-limited Email OTP re-authentication.
- **E4.** Adding, deleting or replacing an individual passkey does not by itself purge or revoke the
  current session, other devices' sessions, session tokens or RP sessions. One-time consumption of
  the used step-up evidence, refusal of future authentication with the deleted passkey, audit and
  notification remain. Response to a separately discovered credential compromise belongs to the
  incident policy.
- **E5.** Security Mode transitions (`NORMAL` ↔ `ADVANCED`), recovery/MFA reset and withdrawal are
  separate events and follow their own session revocation and withdrawal policies.
- **E6.** The identity, step-up, active-count and concurrent-deletion checks for passkey deletion
  live in a shared service, not only in controllers.

### F. Recovery

- **F1.** Case A — a usable passkey remains: the owner signs in normally with it. No recovery
  workflow runs.
- **F2.** Case B — no usable passkey, a Recovery Key exists: Operator approval and a 24 hour
  cooling-off are required.
- **F3.** Case C — no passkey and no Recovery Key: Operator approval, independent strict identity
  verification and a 72 hour cooling-off are required.
- **F4.** Cases B and C never issue an ordinary session. They issue only a recovery session that
  keeps `ADVANCED` and is limited to passkey re-registration. Ordinary access follows
  re-registration and the remaining conditions.
- **F5.** Operator approval is recovery assistance. It does not impersonate the owner and does not
  change the Security Mode. Insufficient evidence is refused.

### G. Sign-up

- **G1.** APP/COM keep their existing surface-specific sign-up routes and checkpoints and start in
  `NORMAL`.
- **G2.** ORG has no public self-service sign-up. `ADVANCED` is completed through invitation,
  Operator approval, prior Entra Identity binding, passkey registration and activation.

### H. Authority

- **H1.** Base (Session, Token and Authorization Authority) owns session and RP authorization
  revocation on Security Mode change and recovery. Auth owns only the authentication ceremonies.

## Open decisions

These are not decided by this ADR and must be resolved before the affected part is implemented:

1. The definition of "two secure authentication methods" required to enable `ADVANCED`: two
   passkeys, or passkey plus Recovery Key; how ORG Entra authentication counts; the explicit rule of
   two at transition and one afterwards.
2. Re-authentication for an owner-initiated `ADVANCED` → `NORMAL` downgrade (existing passkey only,
   or an additional passkey/Recovery Key), and atomicity on partial failure and full session
   revocation.
3. Recovery cases B/C: Case C evidence standard, Operator permissions and approver count, the start
   of the 24/72 hour clock, cancellation, conflicts and retries, and the permissions and issuance
   conditions of the recovery session.
4. ORG sign-up completion conditions and state machine: invitation acceptance, Operator activation,
   Entra pre-registration, required passkey count, Recovery Key, and compensation for multi-database
   failure.
5. Reconciliation against the original WU-2 item list; per-audit-ID coverage is pending.

## Implementation verification requirements

- Rename to `security_mode_id`; migrate reference IDs `1/5/9` to `3/7`; retire the meaning of
  `mfa_level_enabled`; migrate the `0` default; keep ORG at `7`; order backfill before DB
  constraints. Re-survey the latest local `feature` branch before any destructive migration.
- Add regression tests that a single passkey add or delete does not revoke sessions unexpectedly,
  and that Security Mode change and recovery revoke all sessions and RP authorizations.
- Verify operation-bound, one-time step-up evidence for dangerous operations, including actor,
  target ID and session binding.
- Keep related ADRs, docs, code and tests in sync, including `docs/mermaid/` for the
  `security_mode_id` axis.

## Rationale

**Why owner-held mode.** The Security Mode is the owner's choice about how their Identity is
protected. Letting an Operator lower it would make Operator compromise or error a direct path to a
weaker account.

**Why shorter step-up in `ADVANCED`.** An owner who chose phishing-resistant-only authentication
expects a tighter window; one-time, operation-bound evidence removes the reuse the old scope window
allowed.

**Why passkey changes do not revoke sessions.** Routine credential hygiene would otherwise log the
owner out everywhere, discouraging it. Compromise is handled by incident response, not by every
credential edit.

**Why recovery sessions keep `ADVANCED`.** Recovery must restore the owner's protection, not
downgrade it. A recovery session limited to passkey re-registration cannot be used for ordinary
access.

## Related

- `adr/step-up-authentication-redesign.md` — amended by section D.
- `adr/mfa-reset-account-recovery.md` — amended by section F.
- `docs/security/sign-up-sequence.md`
- `docs/security/org-emergency-access.md`
- `docs/security/authentication-assurance-levels.md`
- `docs/security/session-reset-policy.md`
- `app/services/credential_security_transition.rb`
