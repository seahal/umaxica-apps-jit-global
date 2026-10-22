# Social Provider Account Event Notifications

Recorded 2026-10-21. Status: backlog. The user will investigate the providers' notification
mechanisms before any design decision.

## Problem

Google and Apple can tell a relying party, server to server, that something happened to a user's
provider account. UMAXICA handles only part of this, and how UMAXICA should react to each event is
not decided.

## What exists (source reading 2026-10-21, not executed)

- Apple Sign in with Apple server-to-server notifications reach `resources :notifications, only:
  :create` (`config/routes/auth.rb`). `ExternalAuthenticationAppleNotificationProcessor` handles
  `consent-revoked` and `account-deleted`: it sets `ClientExternalIdentity#state` to
  `consent_revoked` / `account_deleted`, records `last_provider_event_at` and revokes the Client's
  sessions (`AuthenticationLogoutAllSessions`). It does not set `released_at`, so the identity keeps
  holding the `(issuer, subject)` unique slot.
- Apple email relay events (`email-disabled` / `email-enabled`) are not handled. UMAXICA does not
  store provider email addresses, so they may not matter; not verified.
- Google Cross-Account Protection (RISC, OpenID Shared Signals; events such as `account-disabled`
  with a hijacking reason, `sessions-revoked`, `tokens-revoked`) has no implementation. A Google
  account disabled for hijacking is therefore invisible to UMAXICA, and existing UMAXICA sessions
  established through it stay alive.
- Event names and semantics above are from prior knowledge; check the providers' current primary
  documentation before designing.

## Questions to answer

1. Which provider events UMAXICA subscribes to, per provider.
2. The reaction per event: identity state, session revocation scope, RP notification (Back-Channel
   Logout through the OP stop primitive), audit record.
3. Whether a revoked or deleted identity may later be re-linked or re-registered, and what happens to
   the old `(issuer, subject)` slot (`released_at`).
4. Verification of inbound provider tokens (signature, issuer, audience, replay) and the endpoint's
   failure behavior.

## Already decided elsewhere

The sign-in / sign-up path behavior when an identity is already in a revoked or deleted state is
decided in the current cycle's requirements (`one.md` D-48, L7); this backlog item covers the
notification mechanisms and the reaction to the events themselves.
