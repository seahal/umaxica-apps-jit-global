# ADR: MFA Reset Account Recovery

**Status:** Accepted (2026-05-18)

> **Amendment (2026-10-15):** `adr/authentication-security-mode.md` section F replaces the single
> 72 hour path for `ADVANCED` actors: Recovery Key cases need Operator approval and 24 hours;
> cases with no passkey and no Recovery Key need Operator approval, strict independent identity
> verification and 72 hours. Recovery issues only an `ADVANCED` recovery session limited to passkey
> re-registration, never an ordinary session, and never downgrades the Security Mode. Not yet
> implemented.

> **Withdrawal (2026-10-15, later):** `adr/authentication-security-cycle-consolidation-2026-10-15.md` withdraws the
> amendment above. `ADVANCED` recovery conditions, including the 24/72 hour proposal, are Pending.
> The general safety principles below remain; their 72 hour wait and Operator approval are not
> re-approved as the final rule for every recovery case.

## Context

The step-up mechanism protects sensitive signed-in operations by requiring a fresh verification with
an already configured step-up method. That model does not answer the account-recovery case where the
actor has lost, destroyed, or can no longer use the configured MFA keys.

Treating MFA reset as a step-up exception would weaken the exact boundary step-up is meant to
enforce: a user who cannot satisfy step-up should not be allowed to bypass it immediately. MFA reset
therefore needs a separate recovery workflow with delay, notification, operator review, audit, and a
forced return to MFA bootstrap.

## Decision

### A. Recovery Boundary

- **A1.** MFA reset is an account-recovery workflow, not a step-up method and not a step-up bypass.
- **A2.** A reset approval never grants immediate access to sensitive actions. After reset, the
  actor must authenticate normally, register a new step-up method through the existing bootstrap
  flow, and satisfy normal step-up before sensitive actions proceed.
- **A3.** Reset is available only for actors that have lost access to all usable MFA credentials for
  the relevant surface.

### B. Request Lifecycle

- **B1.** An actor may have at most one active MFA reset request per account.
- **B2.** A reset request starts a 72 hour cooling-off period. The request cannot be approved before
  that period has elapsed, even by an operator.
- **B3.** During the cooling-off period, the account owner can cancel the request from a session
  that can still satisfy the existing authentication requirements.
- **B4.** Requests that are not completed within the implementation-defined review window expire and
  must be started again.

### C. Notifications And Session Handling

- **C1.** Creating a reset request notifies all registered account notification channels that are
  safe to use for the actor and surface.
- **C2.** Existing sessions must be notified in-product when practical.
- **C3.** While a reset request is active, existing sessions may be restricted when risk justifies
  it. Restricted sessions must not be able to perform sensitive actions without the ordinary step-up
  gate.

### D. Operator Review

- **D1.** After the 72 hour cooling-off period, an operator may approve or deny the request.
- **D2.** The approving operator must be different from the requesting actor. For org actors, an
  operator must not approve their own MFA reset.
- **D3.** Operator approval is a recovery control, not proof that the current browser is trusted.
  Approval only authorizes credential reset and re-bootstrap.

### E. Reset Effects

- **E1.** Approval explicitly revokes existing MFA credentials and passcodes for the actor and
  surface, including passkeys, TOTP credentials, and passcodes that could otherwise be reused.
- **E2.** After revocation, the actor's `multi_factor_status_id` is recalculated. If no
  surface-counting step-up method remains, the status becomes `UNCONFIGURED`.
- **E3.** The actor then follows the existing bootstrap-exempt registration flow to add a new
  step-up method.
- **E4.** Sensitive actions remain blocked until the actor has registered a new step-up method and
  completed normal step-up.

### F. Audit

- **F1.** Reset request creation, cancellation, expiry, denial, approval, and consumption must be
  written to audit logs.
- **F2.** Audit records must include actor identity, target account, operator identity when present,
  timestamps, request status transitions, and non-sensitive reason metadata.
- **F3.** Audit records must not include MFA secrets, passcodes, cookies, bearer tokens,
  authorization headers, or full request parameters.

## Rationale

**Why 72 hours.** A delay gives legitimate owners time to notice and cancel a malicious reset
request through an existing trusted session or notification channel. It also prevents operator
mistakes from turning into immediate account takeover.

**Why operator approval.** A human review step provides a second control for a high-impact recovery
operation. It also creates an auditable point where suspicious requests can be denied.

**Why no early operator override.** Allowing an operator to bypass the 72 hour delay would make the
delay a UI convention rather than a security control. Emergency handling, if ever needed, should be
a separate break-glass ADR with stricter controls.

**Why revoke passcodes.** Passcodes can establish sign-in, so after an MFA reset they may be
compromised, copied, or stale. Reusing them would leave an old sign-in path active after the user
has declared MFA material unavailable.

**Why bootstrap after reset.** The existing step-up redesign already defines `UNCONFIGURED` and
bootstrap-exempt registration for actors with zero surface-counting step-up methods. Reusing that
path keeps reset recovery from inventing a parallel sensitive-action bypass.

## Consequences

- A future implementation must add persistent MFA reset requests with a uniqueness constraint that
  permits only one active request per account.
- Reset request controllers must preserve the authentication, step-up, authorization, and audit
  pipeline order for their surface.
- Operator review must use normal authorization policy checks and must prevent self-approval.
- Credential revocation must be explicit and auditable rather than deleting records silently.
- Product copy must make clear that approval resets MFA credentials; it does not complete login or
  authorize sensitive actions.

## Related

- `adr/step_up-step-up-redesign.md`
- `docs/security/step-up-mfa-status.md`
- `docs/security/mfa-reset-account-recovery.md`
