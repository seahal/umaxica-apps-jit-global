# Sign-in attempt limits per ceremony, and a Switch limit

Status: Backlog. Recorded at the owner's request on 2026-10-28 because it needs analysis before any
decision. Not in scope for the current cycle. Nothing here is a current behaviour contract.

Working-document references: `one.md` D-58 (when each method advances the state machine), R-AU-42
(Switch binding), BL-26.

## Question

For **sign-in** (app; ORG Standby Passkey where noted), should each authentication method have an
attempt limit **per Auth ceremony**, separate from the existing per-IP rate limits?

Methods in scope: Email OTP, Passkey, Secret, social (Google, Apple).

A second, related question: should Switch (sign-in ⇄ sign-up on the same OIDC parent) have a count
limit? The owner decided on 2026-10-28 that Switch is a full toggle with no count limit (R-AU-42),
bounded by the parent's expiry and rate limits. The owner now asks whether that should be revisited.

## Why this came up

D-58 (2026-10-28) makes Passkey and Secret advance the state machine only after a successful proof.
Until then the ceremony stays on its first page, so a user can retry. That is the intended behaviour,
but it means the number of failed proofs within one ceremony is only bounded by IP rate limits.

## Baseline observations

Read at `b6e7871073bdc43a55fc5f05e8476de8ee71252f` (static reading only; nothing was executed):

| Method | What exists today | Per-ceremony failure limit |
|---|---|---|
| Passkey | Per-IP rate limits on options and on verification: 5 per minute and 20 per 15 minutes each (`app/controllers/auth/app/sign/in/passkey/options_controller.rb:24-43`, `verifications_controller.rb:24-43`). Challenges are single-use with a 10-minute TTL. `Webauthn::ChallengeStore::MAX_CHALLENGES_PER_SESSION = 5` only evicts the oldest challenge; it does not limit issuance (`app/services/webauthn/challenge_store.rb:155-159`). | None |
| Email OTP | `EmailOtpPolicy`: 5 failed attempts within 15 minutes locks the **contact** for 15 minutes; 30-second send cooldown (`app/models/concerns/email_otp_policy.rb:6-8, 44-52`). | Per contact, not per ceremony |
| Secret | No `rate_limit` declaration found in `app/controllers/auth/app/sign/in/secrets_controller.rb`; other limits (concern, Rack) not yet checked. | Not found |
| Google, Apple | The provider authenticates the person. Failures on this side are state, binding or provider errors. | None |
| Switch | No `rate_limit` declaration found in `app/controllers/auth/app/sign/switches_controller.rb`. Each Switch issues a new Admission and binding row on the same parent. | None (owner decision: none) |

## Points to analyse

1. Threat per method. Passkey and Google/Apple cannot be brute-forced without the private key or the
   provider account; Secret and OTP can be guessed. The value of a per-ceremony limit differs by method.
2. Where to count. Per ceremony (a fresh Admission resets it), per account (risks letting a third party
   lock someone out), per contact (today's OTP model), per IP (today's rate limits). Per-account lockout
   should be avoided unless the risk is shown to need it.
3. What happens at the limit. Refuse further attempts with the fixed state-mismatch 409 (D-52), keep the
   ceremony otherwise unchanged, and let the person Cancel or start again from the RP. Decide whether
   reaching the limit also ends the ceremony.
4. Whether the existing OTP per-contact lockout should stay, become per ceremony, or both.
5. Secret: confirm whether any limit exists outside the controller before deciding.
6. Switch: each toggle writes history rows. Measure whether the parent's expiry and the existing limits
   already bound it adequately; if not, choose a number and the response when it is exceeded.
7. Logging: reaching a limit should be a distinct, reason-coded event (no secrets or identifiers).

## Not decided

No limit, number or counting scope has been chosen. The current cycle keeps today's behaviour, with
D-58's advance points.
