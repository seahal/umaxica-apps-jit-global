# Sign-in failure convergence table (WU-33, D-91)

Research note, static reading of the working tree based on commit `6e4d70d0b` (2026-10-23), with the
uncommitted changes of the authentication cycle. Nothing was executed for this table. It extends the
first pass in `two.md` 5.4. Implementation of any change waits for WU-27 (D-91).

D-73 classes: **O** ownership mismatch, **R** retryable, **D** definitive refusal of the owner's own
attempt, **F** dependency failure, **I** internal inconsistency, **P** OIDC protocol refusal.

## Shared mapping

`SignInResult` terminal statuses map to HTTP in `app/values/sign_in_result.rb:4-15`:
`session_limit_conflict` 503 (F), `guardrail_blocked` / `login_forbidden` / `access_locked` 403 (D),
`credential_rejected` / `identity_unavailable` / `credential_failed` 401 (D),
`transaction_expired` 410 (D), `failure` / `invalid_request` 400 (D or I, cause-dependent).
Non-terminal: `success`, `session_limit_pending`, `authentication_evidence_recorded`, `mfa_required`.
`SessionLimitGate#render_sign_in_refusal` (`session_limit_gate.rb:141`) renders plain text, default
403, and **defaults the message to the session-limit text for every refusal**.

## Table (surface × method × outcome → class, HTTP today)

| Surface / method | Credential failure | Actor not allowed | Issuance failure | MFA pending | Session-limit pending | OIDC handoff failure |
|---|---|---|---|---|---|---|
| APP Email OTP (`auth/app/sign/in/emails_controller.rb:396-412`) | D, 422 invalid code (OTP budget R) | D, 403 via `render_sign_in_refusal` | F 503 (`session_limit_conflict`) / D 400 | redirect to challenge | evidence recorded, Base resolves | D 400 (binding) |
| COM Email OTP (`auth/com/sign/in/emails_controller.rb`) | same as APP | same | same | same | same | same |
| APP Telephone (sign-in by SMS OTP) | not a sign-in method on Auth today (sign-up only) | — | — | — | — | — |
| APP Secret (`auth/app/sign/in/secrets_controller.rb:53-80`) | D, 422 "invalid secret" | **D shown as 422 "invalid secret"** (cooldown, guardrail, `login_forbidden` share the credential message) | **same 422** | redirect | evidence recorded | D 400 |
| APP Passkey (`in/passkey/verifications_controller.rb`) | D, 401 `verification_failed` (one message, nondisclosure ADR) | D 403 via `render_sign_in_refusal` | F 503 / D | n/a (passkey bypasses MFA) | evidence recorded | D 400 |
| COM Passkey | D, 401 | D 403 — **through `establish_signed_in_session!` directly**, not `AuthenticationSessionCommitter` | same | n/a | evidence recorded | D 400 |
| ORG Passkey Normal (`SignOrgNormalPasskeyCeremony`) | D, 401 | D, 409 + HALT on binding mismatch (WU-32 audit) | F / D | n/a | evidence recorded | D 400 |
| ORG Emergency (`SignOrgStandbyPasskeyCeremony`) | D, 401 | D 403 | F / D | n/a | — | D 400 |
| APP TOTP / MFA Passkey (`in/challenge/*`) | D 422 / 401 | D 403 via `render_sign_in_refusal` | F 503 / D | — | evidence recorded | D 400 |
| APP Google / Apple (`auth/app/omniauth/omniauth_callbacks_controller.rb:499-515`) | P (provider error) → D generic error | D (L2/L3/L5 per D-48) | F / D | n/a | evidence recorded | D 400 |
| ORG Entra (`auth/org/omniauth/omniauth_callbacks_controller.rb:168`) | **one generic 422 error page for every refusal** | same page | same page | n/a | — | same page |

Cross-cutting: Turnstile refusal is R (same page, new challenge, OTP not consumed: WU-04, WU-40);
foreign-browser and stale-binding refusals are O (nothing of the victim consumed: G-8); RP callback
failures land on `/sign/interruption` (D-153, WU-43); OP authorization-request errors are P (WU-42).

## Findings to fix after WU-27

1. APP Secret: non-credential refusals reuse the "invalid secret" 422; split by class.
2. COM Passkey bypasses `AuthenticationSessionCommitter`; route it through the committer like APP.
3. ORG Entra renders one page for every refusal; map to the classes.
4. `render_sign_in_refusal` defaults to the session-limit message; callers must pass the class text.
