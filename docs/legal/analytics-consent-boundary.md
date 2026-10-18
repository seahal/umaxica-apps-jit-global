# Analytics Consent Boundary

## Status

Completed (guard implemented)

## Purpose

This note records the current boundary between:

- strictly necessary service and security processing
- product analytics
- marketing and targeting tracking

The goal is to avoid mixing operational telemetry with optional analytics work before the consent
model is fully implemented.

## Current Repository Signals

The repository contains a complete cookie consent model and UI, plus a server-side guard:

- cookie banner UI
- cookie settings UI
- web cookie consent endpoints
- persisted consent flags for:
  - `consented`
  - `functional`
  - `performant`
  - `targetable`
- **Server-side analytics consent guard** (`app/services/analytics_consent_guard.rb`)

Relevant implementation references:

- `src/controllers/cookie_banner_controller.ts`
- `src/controllers/cookie_toggle_controller.ts`
- `app/controllers/concerns/preference_web_cookie_actions.rb`
- `app/models/actor/preference.rb`
- `app/services/analytics_consent_guard.rb` — Legacy server-side guard retained for future
  consent-aware analytics design
- `app/services/analytics_consent_guard_pre_consent_allowlist.rb` — Exact allowlist of pre-consent
  events

### Runtime Gate Implementation

Current implementation (2026-10-03): the browser-side gate this note originally described,
`installAnalyticsConsentGate()` in `app/javascript/analytics_consent_gate.js`, is not present in the
repository. No file under `src/` loads a product-analytics script, so there is nothing for a
browser-side gate to hold back. `AnalyticsConsentGuard` and its `EventReporterPatch` are referenced
only by their own tests; no initializer installs the patch.

The server-side `AnalyticsConsentGuard` provides:

- Consent checking before any future product analytics emission pipeline
- Silent dropping (with debug logging) of events not in the pre-consent allowlist when `performant`
  consent is missing
- Security, audit, and incident events bypass the guard via `PreConsentAllowlist`

## Current Decision

Until the consent-aware analytics implementation is complete:

- operational telemetry may continue for service reliability and security
- product analytics must remain separate from OTEL
- product analytics should not run before the correct consent category is granted
- marketing or ad-related tracking should not run before the correct consent category is granted

## Working Category Model

### Necessary

This category covers processing that is required to provide, secure, or debug the service.

Examples:

- session and authentication handling
- rate limiting
- anti-bot verification
- critical service error logging
- contact form delivery status

### Functional

This category should remain limited to user-requested convenience behavior.

Examples:

- saved interface preferences
- non-essential UX convenience settings

### Performant

This category is the correct home for product analytics and performance analytics that are not
strictly necessary.

Examples:

- product funnel events
- page and screen flow analysis
- usage analytics
- retention and activation analytics

### Targetable

This category is the correct home for targeting, advertising, and similar tracking.

Examples:

- ad tech
- campaign profiling
- remarketing support

## Turnstile Is Necessary Processing

Cloudflare Turnstile is treated as necessary security and service processing, not optional
analytics. Its verification events belong with service delivery, anti-abuse, and incident-response
logging, so they do not require cookie consent.

## Minimum Safe Rule For Now

Before consent for optional analytics is confirmed, only collect events that are required for:

- security
- fraud or abuse prevention
- service delivery
- incident response

Do not treat product analytics as necessary by default.

## Pre-Consent Event Allowlist

The following event classes may be collected **before** optional `performant` consent is granted.
All other events require `performant` consent.

### Authentication and Identity Events

- `auth.*`
- `authentication.*`
- `authorization.*`
- `session.*`
- `social_auth.*`
- `sign.social.omniauth*` / `sign.social.org.omniauth*`
- `user.token.*` / `staff.token.*`
- `user.occurrence.*` / `staff.occurrence.*`
- `otp.*`
- `webauthn.*` / `sign.webauthn.*`

**Rationale:** Required for service delivery, session management, fraud detection, and audit
accountability. These events answer "who accessed the system and how."

### Security and Anti-Abuse Events

- `rate_limit.*`
- `telephone.verification.rate_limited`
- `turnstile.*`
- `captcha.*`
- `security.*`
- `redirect.blocked` / `redirect.invalid_url`
- `sign.risk.*`

**Rationale:** Required for abuse prevention, bot mitigation, and platform integrity. These events
answer "was an attack or policy violation detected?"

### Incident Response Events

- `health_check.*`
- `exception.*`
- `unhandled_exception`
- `error.unhandled`
- `preference.*.error`
- `preference.*.rotation_error`

**Rationale:** Required for reliability monitoring, incident investigation, and critical failure
notification. These events answer "is the service healthy?"

### Contact Events

- `contact.submission.success`
- `contact.submission.failure`

**Rationale:** Required to confirm delivery of user-initiated contact requests.

## Explicit Rule: Product and Marketing Analytics Remain Disabled

**Product analytics and marketing analytics are DISABLED before `performant` consent is granted.**
The legacy server-side guard was designed to drop event emissions that are not in the pre-consent
allowlist when `Actor.preferences.cookie.performant?` is false.

This means:

- page view analytics
- clickstream analysis
- signup funnel analytics
- onboarding funnel analytics
- feature usage analytics
- retention analytics
- campaign attribution analytics
- advertising pixels and remarketing identifiers

...are all blocked until the user grants `performant` (and `targetable`, where applicable) consent.

## Hold Until Performant Consent

The following event types should remain disabled until the appropriate optional consent is granted:

- page view analytics
- clickstream analysis
- signup funnel analytics
- onboarding funnel analytics
- feature usage analytics
- retention analytics
- campaign attribution analytics

## Hold Until Targetable Consent

The following should remain disabled until targeting consent is granted:

- advertising pixels
- remarketing identifiers
- audience building
- ad network conversion tracking

## Pending Work

1. Define the exact mapping from implementation features to consent categories.
2. Decide whether product analytics uses only `performant` or a refined category model.
3. ~~Add a runtime gate so optional analytics cannot start before consent is available.~~ ✅
   Completed via `analytics_consent_gate.js` and `AnalyticsConsentGuard`
4. Add documentation that matches the final behavior in the privacy and cookie notices.
5. ~~Define the server-side pre-consent event allowlist with rationale.~~ ✅ Completed via
   `PreConsentAllowlist`

## Open Questions

1. Should first-party product analytics always require `performant`, even when implemented without a
   third-party SDK?
2. Should the quick-accept banner action enable only `functional` and `performant`, or all optional
   categories except `targetable`?
3. Should optional analytics be disabled by region until the consent model is complete?

## Related Future Considerations

- `plans/backlog/utm-parameter-adoption-consideration.md` — whether outbound links use UTM
  parameters for campaign attribution. Undecided; any such attribution would be optional analytics
  gated by `performant` consent.
