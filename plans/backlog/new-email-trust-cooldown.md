# New Email Address Trust Cooldown (Proposal)

**Status: PROPOSAL — NOT STARTED. Not yet an accepted decision.**

This is an idea capture, not an active plan. Do not implement from this file until it is promoted to
`specs/` or backed by an accepted ADR.

## Motivation

Account-takeover playbook: an attacker who momentarily controls a session adds an attacker-owned
email, then immediately uses it as a recovery / step-up / sign-in-assist factor to lock the
legitimate owner out. Mature consumer platforms (e.g. X / Twitter) mitigate this by treating a
freshly added email as **not yet trusted for ~1 day**: it works as a contact address right away, but
cannot be used to take over the account during the cooldown window, and the legitimately trusted
addresses are notified so the owner can react.

We want the same property here.

## Proposed Policy

Adding a new email address to an existing account:

1. **Step-up required on the existing session.** Adding an email is a sensitive operation; require a
   successful step-up (step-up) before the add is accepted. Reuses the existing step-up pipeline —
   see [`adr/step-up-authentication-redesign.md`](../../adr/step-up-authentication-redesign.md) and
   `plans/active/step-up-authentication-rebuild.md` (historical source unavailable;
   re-establish its contract before relying on it).
2. **New email verification is immediate.** The newly added address may be verified right away
   (normal OTP / verification link). Verification proves control of the mailbox; it does **not** by
   itself confer account trust.
3. **Notify existing trusted emails.** Send an "an email address was added to your account"
   notification to the already-trusted address(es), not to the newly added one. This is the owner's
   out-of-band signal that something changed.
4. **Cooldown before the new email is trusted.** For a defined period after it is added/verified,
   the new email must NOT be usable for:
   - Step-up / step-up
   - Account recovery
   - Sign-in assistance (e.g. "email me a sign-in link", identifier hints)

   During the cooldown the address is "verified but untrusted": valid as a contact/notification
   target only. After the cooldown elapses it graduates to a trusted factor.

## Open Questions (resolve before promoting to active)

- **Cooldown duration.** X uses ~1 day. Confirm the exact window and whether it differs per surface
  (`app` / `org` / `com`). `org` (staff) may warrant a longer or differently-gated window.
- **Where trust state lives.** Need a persisted per-email field such as `trusted_at` /
  `usable_for_recovery_from` rather than a class/thread/global flag (per AGENTS.md non-negotiables).
  Coordinate with
  `plans/backlog/customer-email-telephone-encryption-plan.md` (historical source unavailable)
  and the contact-actor restoration work
  (`restoration-e1-contact-actor-context.md` (historical source unavailable),
  `restoration-e2-contact-customer-canonicalization.md` (historical source unavailable)).
- **Last-factor edge case.** If the account currently has no other trusted email/factor, define
  behavior — does the first email get a cooldown, or is bootstrap (sign-up) exempt while only
  _additional_ emails are gated?
- **Cooldown bypass.** Decide whether a stronger proof (e.g. passkey + the notified old email
  confirming) can shorten/cancel the cooldown, and whether the owner can cancel a pending add from
  the notification.
- **Surface scoping.** Confirm the policy is applied per surface boundary and does not leak
  contact/trust state across `app` / `org` / `com`.

## Relationship to Existing Work

- Step-up dependency: `adr/step-up-authentication-redesign.md`,
  the unavailable historical step-up rebuild plan; its requirements are not reconstructed here.
- Contact/email model and encryption: `restoration-e1-contact-actor-context.md`,
  `restoration-e2-contact-customer-canonicalization.md`,
  `customer-email-telephone-encryption-plan.md`.
- Email OTP race hardening (verification path): `adr/email-otp-race-condition-fixes.md`.

## Next Step

When prioritized: answer the open questions, capture the trust-state model as an ADR (sensitive
auth/account-recovery decision), then move an implementation plan into `specs/`.
