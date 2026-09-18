# Sign-In State Machine Phase 0 Matrix

Date: 2026-05-20

## Scope

This note records the Phase 0 route/action matrix used before rebuilding the sign-in cycle status
model. It is implementation context, not stable product documentation.

## Shared Entry And Handoff Points

| Area                       | Current entry points                                   | Target status                   | Token phase      | Notes                                                                                                  |
| -------------------------- | ------------------------------------------------------ | ------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------ |
| Sign-in entry              | `GET /sign/in`, credential-specific `new` actions      | `PRIMARY_PENDING`               | pre-token        | Starts or resumes the DB-backed sign-in cycle. Signed-in actors are rejected.                          |
| Primary credential submit  | email/passkey/passcode verification actions            | `PRIMARY_PENDING` -> next state | pre-token        | Ordinary input errors remain at `PRIMARY_PENDING`; successful primary credential binds `principal_id`. |
| Sign-in MFA challenge      | `/sign/in/challenge`, method-specific challenge routes | `MFA_PENDING`                   | pre-token        | Sign-in MFA is AAL1 session establishment only; it must not satisfy AAL2 step-up.                      |
| Session-limit management   | `/sign/in/session`                                     | `SESSION_LIMIT_PENDING`         | restricted-token | Restricted token remains, but `SessionLimitGate` stops being authoritative in later phases.            |
| Guardrail                  | sign-in guardrail participant                          | `GUARDRAIL_PENDING`             | pre-active-token | Stack/evaluator participant. Empty stack advances; blocking stack stops generically.                   |
| Session issuance           | internal issuance boundary                             | `SESSION_ISSUANCE_PENDING`      | token issuance   | Single-use; token DB writes and cycle transition happen before cookies/headers.                        |
| Checkpoint                 | `/sign/in/checkpoint`                                  | `CHECKPOINT_PENDING`            | active-token     | Stack/evaluator participant; bulletin remains an initial item source.                                  |
| Dashboard sequence         | `/dashboard` reached by sequence                       | `DASHBOARD_PENDING`             | active-token     | Distinct from ordinary dashboard access.                                                               |
| Return/default destination | safe `rt` or configuration path                        | `RETURN_PENDING`                | active-token     | Only sequence path consumes `rt`; ordinary dashboard access does not.                                  |

## Surface Route Matrix

| Surface | Primary methods                                       | MFA methods             | Session-limit route        | Checkpoint route              | Notes                                                                              |
| ------- | ----------------------------------------------------- | ----------------------- | -------------------------- | ----------------------------- | ---------------------------------------------------------------------------------- |
| `app`   | email OTP, passkey, passcode, social callback handoff | TOTP, passkey challenge | `sign_app_in_session_path` | `sign_app_in_checkpoint_path` | App also has sign-up handoffs that call `establish_signed_in_session!`.            |
| `com`   | email OTP, passkey, passcode                          | passkey challenge       | `sign_com_in_session_path` | `sign_com_in_checkpoint_path` | Com has no TOTP sign-in MFA in current route set.                                  |
| `org`   | passkey, passcode, Google social callback handoff     | passkey challenge       | `sign_org_in_session_path` | `sign_org_in_checkpoint_path` | Org sign-up is not normal end-user sign-up; operator acquisition remains separate. |

## Policy Method Mapping

| Target status              | Participant/action family                 | Policy method           |
| -------------------------- | ----------------------------------------- | ----------------------- |
| `PRIMARY_PENDING`          | show primary credential entry             | `show_primary?`         |
| `PRIMARY_PENDING`          | verify primary credential                 | `verify_primary?`       |
| `MFA_PENDING`              | show MFA participant                      | `show_mfa?`             |
| `MFA_PENDING`              | verify MFA participant                    | `verify_mfa?`           |
| `SESSION_LIMIT_PENDING`    | manage restricted session/session limit   | `manage_session_limit?` |
| `GUARDRAIL_PENDING`        | evaluate guardrail stack                  | `run_guardrail?`        |
| `SESSION_ISSUANCE_PENDING` | issue signed-in session                   | `issue_session?`        |
| `CHECKPOINT_PENDING`       | show checkpoint participant               | `show_checkpoint?`      |
| `CHECKPOINT_PENDING`       | clear checkpoint participant item         | `complete_checkpoint?`  |
| `DASHBOARD_PENDING`        | show sequence dashboard participant       | `show_dashboard?`       |
| `RETURN_PENDING`           | consume safe return/default destination   | `consume_return?`       |
| any non-terminal           | explicit owner-initiated terminal failure | `fail?`                 |

## Phase 1 Boundary

Phase 1 only rebuilds model/status state and transition tests. Controller wiring, DB-backed cycle
lookup, policy integration, session issuance, session-limit replacement, and participant stacks are
later phases.
