# Sign Withdrawal And Membership

> **Deprecated / partially superseded by Identity Authority inversion:** `acme/www` is the Session,
> Token, Account, Preference, Authorization, and downstream-token Authority. `sign/id` is
> ceremony-only: it may host credential entry points and execute delegated credential ceremonies,
> but it must not own sessions, refresh tokens, preference writes, dashboards, account lifecycle,
> token issuance, logout, or step-up freshness. Existing sign-side physical tables/models do not
> imply sign-side authority. Do not use this document to reintroduce sign-side sessions, refresh,
> preference, dashboard, account lifecycle, token issuance, logout, or step-up freshness.

This document describes the current Client/Visitor withdrawal and membership behavior for the sign
configuration surfaces. It is not the lifecycle contract for Persona or Organization resources. The
adopted resource lifecycle, once enabled, is documented separately in
`docs/architecture/persona-organization-authority.md`; the recovery behavior below must not be
copied to those resources. Until the required authority migration and lifecycle integration are
complete, this document records the existing principal withdrawal contract and its explicit recovery
window.

## Surface Policy

| Surface | Actor      | Self-service withdrawal | Membership handling                                |
| ------- | ---------- | ----------------------- | -------------------------------------------------- |
| `app`   | `Client`   | Yes                     | Client-controlled account lifecycle                |
| `com`   | `Visitor`  | Yes                     | Visitor-controlled account lifecycle               |
| `org`   | `Operator` | No                      | Direct-message request handled by another operator |

## App And Com Withdrawal

The `app` and `com` surfaces should use the same withdrawal business logic.

The implementation uses a DB-backed withdrawal cycle with shared model/controller concerns and
separate surface models. Controllers remain surface-specific because routes, current actor helpers,
redirects, translations, and audit event names differ between `app` and `com`. Business rules must
not drift between the two surfaces.

Withdrawal scheduling, recovery, and early irreversible termination require recent token-scoped AAL2
step-up with exact scope `withdrawal`. A fresh sign-in session is only AAL1 and must not satisfy
this gate. A recent step-up recorded for another scope, or a legacy generic verification scope, must
be rejected.

### App And Com Sequence

The user-visible sequence is distinct from the state-machine status names.

1. Normal state
   - The actor has no active withdrawal cycle.
   - `discarded_at` and `purged_at` are the retention sentinel values.

2. Withdrawal flow entry
   - A withdrawal cycle is created and records `began_at`.
   - This means the actor entered the withdrawal flow, not that the account has been scheduled for
     withdrawal.
   - `withdrawal_started_at`, `deactivated_at`, `discarded_at`, and `purged_at` are not changed.
   - Other sessions are not revoked.
   - The configuration history can show that the withdrawal process was opened.

3. Withdrawal scheduled
   - The actor explicitly confirms withdrawal intent.
   - `withdrawal_started_at` records the point where the actor entered the withdrawal-scheduled
     state.
   - The cycle transitions through `CLOSING`.
   - RP/OIDC actions should reject the actor after this point.
   - Normal sign/acme access should be constrained to withdrawal/status/recovery paths as
     appropriate for the surface.

3'. Logical deletion and recovery window

- The withdrawal is finalized by setting `discarded_at` to the logical deletion time.
- `purged_at` is set to `discarded_at + 31.days`.
- The cycle transitions to `DISCARDED`.
- Every session of the actor is revoked, including the requesting session, and the auth cookies are
  cleared.
- Withdrawal status, recovery, and early termination continue through the withdrawal ceremony, not
  through a session.
- The account row is not physically deleted by self-service withdrawal.

3''. Recovery

- Recovery is available only after one hour has elapsed from `discarded_at` and before `purged_at`.
- Recovery clears the withdrawal scheduling timestamps and restores `discarded_at` and `purged_at`
  to the retention sentinel values.

4. Scheduled termination and anonymization
   - Retention jobs pick up actors whose `purged_at` has elapsed.
   - The actor is marked terminated and personally identifying data is anonymized.
   - Audit information is retained.

Account withdrawal does not directly purge direct-message content, audit records, activity history,
or legal-hold-sensitive records. Those records follow their own retention, disclosure response, and
legal hold policies; message retention rules must be finalized before any direct-message launch.

Early irreversible termination may be added as an explicit exception branch, but it is not the
primary app/com self-service sequence. When available, it remains behind the same `withdrawal`
step-up scope as scheduling and recovery.

### App And Com State Machine

The withdrawal cycle status tracks the withdrawal procedure. The actor row remains the source of
truth for access and retention through `withdrawal_started_at`, `discarded_at`, `purged_at`, and
`terminated_at`.

The status reference tables are surface-specific, not shared:

- `ClientWithdrawalCycleStatus`
- `VisitorWithdrawalCycleStatus`

The intended status IDs are:

| Status       | ID  | Meaning                                                 |
| ------------ | --- | ------------------------------------------------------- |
| `NOTHING`    | 0   | Placeholder / no meaningful procedure state             |
| `REQUESTED`  | 10  | The actor entered the withdrawal flow                   |
| `CLOSING`    | 20  | The actor explicitly confirmed withdrawal scheduling    |
| `DISCARDED`  | 30  | Logical deletion is active and `purged_at` is scheduled |
| `RECOVERED`  | 40  | The actor recovered before `purged_at`                  |
| `TERMINATED` | 100 | The actor has been anonymized and cannot recover        |
| `FAILED`     | 900 | The withdrawal procedure failed                         |

The intended transitions are:

```text
NOTHING -> REQUESTED
REQUESTED -> CLOSING
CLOSING -> DISCARDED
DISCARDED -> RECOVERED
DISCARDED -> TERMINATED
REQUESTED -> FAILED
CLOSING -> FAILED
DISCARDED -> FAILED
```

`REQUESTED` and `CLOSING` are intentionally separate. `REQUESTED` means the actor only opened the
withdrawal flow. `CLOSING` means the actor explicitly agreed to schedule withdrawal.

### Configuration History

The configuration history should show the withdrawal process, not only the final actor state.
Withdrawal cycle events should therefore be recorded separately from the cycle's current status.

Expected app/com event records:

- `ClientWithdrawalCycleEvent`
- `VisitorWithdrawalCycleEvent`

At minimum, each event should record the cycle, the previous and next status, the occurrence time,
the actor, the session token where available, and a compact reason/kind value. The configuration
history can read these events, while audit/chronicle remains the long-lived security audit trail.

The app/com implementation shares controller behavior through controller concerns and domain
behavior through model/cycle concerns. The lifecycle service is only an orchestration boundary for
locking, actor timestamp mutation, cycle transitions, event recording, and session revocation.

## Org Membership And Withdrawal

The `org` surface does not provide self-service join or withdrawal.

Operators request join, withdrawal, or membership adjustment for operational handling. Direct
message is still not implemented, so the sign org surface records these as org-specific operator
lifecycle requests. Another operator must approve and execute the request after MFA step-up.

Org withdrawal is intentionally not aligned with the app/com self-service sequence yet. For now, the
sign org surface should stop at recording the operator's request to withdraw or adjust membership.
Execution, approval, and any later lifecycle state machine require a separate design.

Operator lifecycle requests are intentionally separate from the app/com withdrawal service. The org
workflow tracks the requester, approver, executor, action, status, target operator or invitation
email, and resulting invitation where applicable. Join execution creates an organization invitation;
withdrawal or suspension execution revokes the target operator's active sessions and sets the
operator withdrawal timestamps.

Do not add destructive org self-service withdrawal behavior under the sign org configuration surface
without a new accepted ADR.

## Related Decisions

- `adr/sign-withdrawal-and-membership-surface-policy.md`
