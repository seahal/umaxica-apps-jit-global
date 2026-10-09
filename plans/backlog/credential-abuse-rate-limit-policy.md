# Credential Abuse Rate Limit Policy

**Status: PROPOSAL - NOT STARTED. Not yet an accepted decision.**

This is a design capture for rate limits, cooldowns, and inventory caps around authentication,
credential management, outbound delivery, and sessions. Do not implement from this file until it is
promoted to `specs/` or backed by an accepted ADR.

## Motivation

Authentication and contact surfaces have asymmetric cost and risk. An attacker with no effective
limit can:

- burn SMS or email delivery budget;
- brute-force OTP, passcode, or recovery flows;
- churn account identifiers and credential inventory;
- create excessive sessions or session-management pressure;
- abuse social-login linking or unlinking as an account-takeover step.

The application already has several local controls:

- default Rails-native request rate limiting through `RateLimit`;
- sign-in login cooldown;
- email / telephone OTP cooldowns and attempt lockouts;
- step-up method cooldowns and ticket-scoped attempt lockout;
- per-surface active and restricted session limits.

The missing piece is a documented product policy that defines which operations need limits, what
dimensions they use, and what time windows are required.

## Policy Shape

Every sensitive or externally expensive operation should define a limit tuple:

```text
operation, subject, target, discriminator, time_window, max_count, response, audit_event
```

- `operation`: the action being limited, such as `sms_otp_send` or `email_address_change`.
- `subject`: actor when known, otherwise session, IP, device, or anonymous cycle.
- `target`: email address, telephone number, credential record, provider identity, or token.
- `discriminator`: normalized key used for counting. Do not use raw full params.
- `time_window`: one of the standard windows below.
- `max_count`: allowed count in that window.
- `response`: generic user-facing result, usually HTTP 429 for request limits.
- `audit_event`: occurrence or audit record when the limit matters operationally.

## Standard Windows

Use these windows for policy tables unless a narrower technical cooldown is explicitly justified:

| window       | purpose                                                                  |
| ------------ | ------------------------------------------------------------------------ |
| all-time     | hard inventory caps and non-renewable safety limits                      |
| 1 year       | long-term abuse history, provider trust, account recovery anomaly review |
| 1 month      | account or identifier churn limits                                       |
| 1 week       | repeated credential-management or recovery activity                      |
| 1 day        | external-cost limits and suspicious account-change dampening             |
| 1 hour       | user-visible throttles and attack-rate control                           |
| 5-15 minutes | OTP attempt windows, sign-in cycles, step-up tickets                     |
| 5-60 seconds | resend cooldown, double-submit control, WebAuthn replay dampening        |

Short cooldowns are UX controls and double-submit protection. They do not replace hour/day/month
abuse limits for costly or security-sensitive operations.

## Initial Candidate Limits

These are starting values for discussion, not final product commitments.

| operation                         | discriminator                             | candidate limits                           | notes                                                                  |
| --------------------------------- | ----------------------------------------- | ------------------------------------------ | ---------------------------------------------------------------------- |
| SMS OTP send                      | normalized telephone + IP + actor/session | 1/min, 5/hour, 10/day, 30/month            | Highest direct cost. Count successful send attempts, not only accepts. |
| Telephone registration / change   | actor + normalized telephone + IP         | 3/hour, 5/day, 20/month                    | Also requires step-up when actor is signed in.                         |
| Email OTP send                    | normalized email + IP + actor/session     | 1/min, 10/hour, 30/day, 100/month          | SES cost and anti-spam control.                                        |
| Email address registration/change | actor + normalized email                  | 4/hour, 10/day, 20/month                   | Similar to public platform account-change throttles.                   |
| New email trust graduation        | email credential record                   | 1 day trust cooldown                       | See `plans/backlog/new-email-trust-cooldown.md`.                       |
| Passkey registration              | actor + session/device                    | 5/hour, 20/day                             | Low direct cost but high account-takeover impact.                      |
| Passkey assertion / step-up       | actor + credential/session                | 5 sec cooldown, 5 failures per ticket      | Current step-up ADR already defines this shape.                        |
| Passcode issue / verify           | actor/identifier + IP                     | 5/hour issue, 5 failures per cycle         | Exact model depends on passcode flow consolidation.                    |
| TOTP verify                       | actor + session/cycle                     | 5 failures per cycle, short retry cooldown | Avoid account-wide lockout unless abuse data justifies it.             |
| Google / Apple link               | actor + provider subject                  | 5/day, 20/month                            | Link requires recent AAL2 when actor is already signed in.             |
| Google / Apple unlink             | actor + provider subject                  | 5/day, 20/month                            | Must preserve AAL1 inventory according to existing ADR.                |
| Sign-in session issuance          | actor + token model                       | existing active/restricted session limits  | Current stable doc: `docs/security/session-limit.md`.                  |
| Revoke all sessions               | actor + token/session                     | 3/hour, 10/day                             | Requires scoped AAL2 and audit.                                        |
| Step-up ticket verification       | token-bound step-up session               | 5 failures per ticket, 15 min TTL          | Current ADR: `adr/step-up-authentication-redesign.md`.                 |

## Inventory Caps

Inventory caps are all-time/current-state limits, not rolling rate limits. They should be enforced
with model/service-level checks and DB constraints where practical.

The earlier candidate cap table in this proposal was discarded because the implementation values are
the more accurate baseline. Future work should inventory current model constants first, then propose
intentional changes as separate implementation items.

## Enforcement Principles

- Enforce the limit at the narrowest service boundary that actually performs the expensive or
  sensitive operation. Controller-level checks may short-circuit, but they must not be the only
  authority.
- Use normalized identifiers and hashed discriminators for email and telephone keys where possible.
  Do not log raw tokens, cookies, authorization headers, OTPs, or full request params.
- Apply layered keys for outbound delivery: per IP, per normalized target, per actor when known, and
  per session/cycle for anonymous flows.
- Return generic messages for identifier-based flows to avoid account enumeration.
- Count attempted sends before or atomically with enqueueing the outbound job so concurrency cannot
  double-send.
- Keep `app`, `com`, and `org` surface boundaries separate unless a shared abstraction already
  exists.
- Prefer existing Rails-native `RateLimit`, Rails cache / Valkey counters, occurrence records, and
  credential-inventory services over adding a second rate-limit framework.

## Documentation Target

If accepted, split this proposal into:

1. An ADR for product-level rate-limit and credential-inventory decisions.
2. `docs/security/credential-rate-limits.md` for current behavior after implementation.
3. An implementation plan under `specs/` with per-surface rollout and tests.

## Open Questions

- Which limits are hard-blocking versus soft controls that trigger CAPTCHA, additional step-up, or
  manual review?
- Should org/staff limits be stricter than app/com because operator accounts have higher impact?
- Which occurrence/audit table owns long-window counters that outlive cache TTLs?
- Which identifiers must be HMACed before being used as rate-limit discriminators?
- Are monthly/yearly windows product requirements, compliance controls, or anomaly signals only?
- Should SMS daily/monthly limits be lower until real delivery cost and abuse data are available?
- How should support override a false positive without weakening ordinary self-service controls?

## Related Material

- `adr/authentication-assurance-level-boundaries.md`
- `adr/step-up-authentication-redesign.md`
- `adr/chronicle-audit-db-consolidation.md`
- `docs/security/authentication-assurance-levels.md`
- `docs/security/session-limit.md`
- `plans/backlog/new-email-trust-cooldown.md`
- `plans/backlog/operational-logging-foundation.md`
- `plans/backlog/email-and-sms-not-delivering-via-request-flow.md`
