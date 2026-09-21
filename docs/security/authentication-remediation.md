# Authentication Remediation Evidence

This document records repository evidence for the July 2026 authentication remediation work. It is
not a compliance attestation. Treat each row as evidence that can be re-run or inspected, and keep
unresolved gaps explicit.

## Remediated Slices

| Slice | Area                        | Repository evidence                                                                                            | Remaining gap                                      |
| ----- | --------------------------- | -------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| F3    | Ceremony cleanup            | `config/recurring.yml` schedules every dedicated ceremony transaction purge job in production.                 | Cleanup observability is still service-specific.   |
| F1    | Timing protection           | `MinimumResponseBudget` defaults on when included; credential endpoint contract tests pin coverage.            | Additional endpoint families need review as added. |
| F7    | OP route contract           | Base routes expose discovery, JWKS, `/oauth/*`, and `/oidc/logout` through existing OP controllers.            | Deployment naming still uses transitional `base`.  |
| F2    | Flash removal               | `auth/app/sign/in/sessions` now uses explicit render state instead of Rails flash.                             | Other auth/base surfaces still need migration.     |
| F5/F6 | Route terminology and TODOs | Route comments no longer describe Base as a credential gateway, and stale degraded-entrypoint text is removed. | None for the comments changed in this slice.       |
| F4    | Session commit seam         | App sign-in and app social completion route through `AuthenticationSessionCommitter`.                          | Full authority migration remains transitional.     |
| F7b   | Admission control key shape | Telephone verification pacing uses IP plus telephone blind-index digest, never the raw number.                 | Other credential rate-limit keys need review.      |
| F8    | Auth security events        | `AuthenticationSecurityEventEmitter` writes sanitized events to `Chronicle` under the existing security retention policy and also emits a redacted operational log; the existing SMS transport records enqueue/provider acceptance/failure facts without recipient or message content. | Email provider receipts, provider callback/retry contracts, and taxonomy-wide caller migration remain separate follow-up work. |

## Current Route Matrix

| Route family                        | Owner in this repository | Responsibility                                                    |
| ----------------------------------- | ------------------------ | ----------------------------------------------------------------- |
| `/.well-known/openid-configuration` | `base`                   | OP discovery document.                                            |
| `/.well-known/jwks.json`            | `base`                   | OP signing-key publication.                                       |
| `/oauth/authorize`                  | `base`                   | OP authorization endpoint.                                        |
| `/oauth/token`                      | `base`                   | OP token endpoint.                                                |
| `/oauth/userinfo`                   | `base`                   | OP userinfo endpoint.                                             |
| `/oauth/revoke`                     | `base`                   | OP token revocation endpoint.                                     |
| `/oidc/authorization`               | `base`                   | First-party RP authorization start.                               |
| `/oidc/callback`                    | `base`                   | First-party RP callback.                                          |
| `/oidc/backchannel/logout`          | `base`                   | RP backchannel logout consumer.                                   |
| `/oidc/logout`                      | `base`                   | OP logout endpoint.                                               |
| `/social/:provider/sign/in`         | `auth`                   | Sign ceremony entry into social sign-in.                          |
| `/social/:provider/sign/up`         | `auth`                   | Sign ceremony entry into social sign-up.                          |
| `/social/:provider/callback`        | `auth`                   | Social provider callback handled as credential ceremony evidence. |

`/oauth/*` is OP-only. First-party RP callbacks stay under `/oidc/callback`, and social federation
entry/callback routes stay under `/social`.

## Ceremony Cleanup Lifecycle

Dedicated ceremony purge jobs reclaim expired or abandoned ceremony transaction rows using each
transaction table's expiration semantics. `RetentionPurgeJob` remains responsible for retention rows
that expose `purge_eligible_at`; it is not the ceremony transaction scheduler.

Cleanup must preserve active, non-expired ceremonies and be safe to run repeatedly. After cleanup,
retry starts a new ceremony and must not reuse stale nonce, verifier, challenge, token, or candidate
state from the abandoned transaction.

## Timing And Enumeration Mitigation

Credential endpoints that include `MinimumResponseBudget` now receive a response budget by default.
Endpoints with an alternative timing strategy, such as email sign-in dummy OTP work, must be
explicitly represented in the credential timing contract test.

New credential endpoints must choose one of:

- include `MinimumResponseBudget`;
- prove an equivalent dummy-work path in a contract test;
- explicitly opt out with a reason and a focused test.

## Admission Control Evidence And Gaps

Existing code contains session-limit managers, token status models, restricted-session handling, and
rate-limit profile infrastructure. Telephone verification short-window pacing now uses a composite
IP plus telephone blind-index digest key, avoiding raw telephone values in cache keys while reducing
IP-only NAT blast radius.

Deferred checks:

- confirm Client, Visitor, and Operator active and total session limits against
  `docs/security/session-limit.md`;
- add a race-sensitive concurrent sign-in test around the session-limit manager;
- verify sign-in, sign-up, TOTP, passkey, recovery, and social submit limits use privacy-safe keys;
- ensure raw email, telephone, provider UID, token, verifier, challenge, and recovery secret values
  are never used directly in rate-limit keys.

## Logging And Audit Evidence And Gaps

The repository has chronicle policies, JWT anomaly persistence, CSP violation logging, social nonce
failure logging, and Redis credential masking tests. `AuthenticationSecurityEventEmitter` defines the
current authentication security-event taxonomy, writes the sanitized event to `Chronicle` using the
existing `security` retention policy, and emits a separately redacted operational log. Chronicle is
the retained audit record; the application log remains diagnostic and is not a substitute for it.

Deferred checks:

- wire remaining taxonomy events to their current controllers/services where a real security event
  exists; do not manufacture events for code paths that do not currently emit them;
- add leakage tests proving logs and audit payloads exclude tokens, cookies, verifiers, challenges,
  TOTP secrets, recovery secrets, and full request parameters;
- document retention, masking, SIEM export readiness, and incident-response ownership;
- add email/provider delivery receipt records only after a concrete provider callback, retry, and
  retention contract is approved. Enqueue or provider acceptance must not be reported as delivery
  completion;

## Standards Evidence Map

| Standard        | Area                        | Repository evidence                                               | Gap                                            | Action                                          |
| --------------- | --------------------------- | ----------------------------------------------------------------- | ---------------------------------------------- | ----------------------------------------------- |
| OWASP ASVS      | Authentication              | Timing contract and ceremony cleanup tests.                       | Full endpoint inventory remains open.          | Keep credential endpoint contract current.      |
| OWASP ASVS      | Session management          | Existing session-limit and token-family code.                     | Race and limit matrix not fully reverified.    | Add focused session-limit race tests.           |
| OWASP ASVS      | Access control              | Surface-specific controller and route contracts.                  | Authority-boundary migration still partial.    | Continue Sign-to-Acme seam work.                |
| OWASP ASVS      | Logging                     | JWT anomaly, CSP, nonce, and masking tests.                       | No single auth event taxonomy.                 | Add taxonomy and event contract tests.          |
| OWASP WSTG      | Authentication testing      | Credential timing and OP route contract tests.                    | Manual abuse-flow evidence incomplete.         | Add explicit abuse-flow regression tests.       |
| OWASP WSTG      | Session testing             | Existing session-limit coverage plus route contracts.             | Logout/token resurrection checks need review.  | Re-run focused logout/session tests after F4.   |
| NIST SP 800-63B | Authenticator lifecycle     | Passkey/TOTP/secret ceremony cleanup scheduling.                  | Enterprise authenticator lifecycle map open.   | Extend lifecycle docs per authenticator.        |
| NIST SP 800-63B | Replay resistance           | OIDC, state, nonce, and consumed-JTI code exists.                 | End-to-end replay evidence not consolidated.   | Add replay evidence matrix.                     |
| NIST SP 800-63C | Federation                  | OP route contract and discovery endpoint route tests.             | Federation conformance is not asserted.        | Add protocol-level federation contract tests.   |
| ISO/IEC 27001   | Access control and logging  | Authorization policies and chronicle policy tests.                | Control ownership and retention not complete.  | Assign audit schema owner and retention policy. |
| ISO/IEC 27002   | Identity and authentication | Surface route matrix and credential ceremony docs.                | Admission matrix still deferred.               | Finish Slice 7 with clean baseline.             |
| ISO/IEC 29119   | Test evidence               | Focused remediation tests and route contracts.                    | Baseline broad suite currently failing.        | Stabilize unrelated route/helper failures.      |
| ISO/IEC 25010   | Security and reliability    | Idempotent cleanup tests and secure-default timing concern tests. | Performance impact not measured.               | Add bounded timing-budget test config review.   |
| ISO/IEC 26514   | Documentation quality       | Updated route, cleanup, timing, and namespace mapping docs.       | Some older docs still use superseded language. | Continue docs drift cleanup by source priority. |
