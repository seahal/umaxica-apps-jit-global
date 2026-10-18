# ADR: Preference Scope and Browser Persistent State Separation

**Status:** Accepted (2026-09-26)

## Context

The Preference mechanism already persists user-selected display and usage settings in the browser.
Because it is an existing browser-persisted channel, new features that need state to survive across
requests are tempted to store that state in Preference as well.

Browser storage is an implementation similarity, not a shared responsibility. Merging unrelated
browser state into Preference would let a display-settings mechanism influence authentication,
account identification, tenancy, and other security boundaries.

## Decision

A requirement to persist state in the browser MUST NOT, by itself, justify adding that state to the
existing Preference mechanism.

Preference is limited to user-selected display and usage settings such as language, region, time
zone, and theme.

When a new feature needs browser-persistent state of any other kind, it MUST NOT be added to
Preference. Each such use gets its own dedicated cookie and server-side state management. Examples:

- accounts previously used in this browser;
- persistent browser-specific identifiers;
- feature state that must survive across the sign-in or sign-up boundary;
- per-browser records for a specific feature;
- state with security or privacy significance.

Cookie name, retention period, `Secure`, `HttpOnly`, `SameSite`, `Path`, host scope, revocation
conditions, and the mapping to server-side data are defined individually as requirements of the
owning feature.

## Rationale

Merging Preference with other browser-persistent state creates these risks:

1. Preference corruption or expiry halts sign-in, sign-up, or other authentication paths.
2. The Preference cookie lifecycle becomes coupled to the lifecycles of authentication, browser
   identification, and similar state.
3. The meaning of sign-out, cookie deletion, revocation, and rotation becomes ambiguous.
4. Data that needs different cookie attributes or retention periods is forced under one security
   policy.
5. Each new responsibility added to Preference widens the blast radius into existing
   authentication, tenancy, and browser-continuity handling.
6. Over time, Preference risks degrading into a de facto general-purpose browser session.

Data meaning, authority, lifecycle, and failure blast radius therefore take precedence over the
shared implementation detail of being stored in the browser.

## Rule

When implementing new browser-persistent state, decide:

- Is it purely a user-selected setting?
  - Yes: it is a Preference candidate.
  - No: do not add it to Preference.
- Can the value reveal an account, authentication state, usage history, tenant, or other principal
  information?
  - Yes: use an independent mechanism.
- Must the feature or authentication flow keep working when Preference is unavailable?
  - Yes: use an independent mechanism.
- Does it need a retention period, revocation condition, cookie attribute, or deletion operation
  different from Preference?
  - Yes: use an independent mechanism.

An independent mechanism SHOULD use a dedicated cookie name. Where appropriate, the cookie holds only
an opaque identifier and the actual data is managed server-side.

### Continuity Cookie

The cookie name `continuity` is reserved for state that persistently belongs to a single browser.

Its responsibility is separate from `auth` and `preference`. Information stored in or associated
with `continuity` is limited to state scoped to the browser alone.

The following MUST NOT be part of the `continuity` responsibility:

- current authentication state or authentication credentials;
- authorization, roles, or permissions;
- OAuth/OIDC access tokens, refresh tokens, or other credentials;
- account-specific Preference;
- Persona-specific Preference;
- Organization- or tenant-specific state;
- state that is expected to synchronize with other browsers or devices.

The presence or content of `continuity` alone MUST NOT be used to establish the user's identity,
sign-in state, membership, or permissions.

When `continuity` is expired, missing, corrupted, or unavailable, normal `auth` and `preference`
processing MUST continue unaffected.

The name `continuity` MUST NOT be used for a cookie with any other purpose.

## Consequences

- Preference stays small and is not used as general-purpose storage for all browser state.
- Each new browser-persistent feature designs its own cookie, data model, revocation rules, deletion
  rules, and security boundary.
- A growing number of cookies is an accepted cost, preferable to blurring security boundaries by
  consolidating state with different responsibilities into one cookie or into Preference.

## Related

- `adr/preference-soft-bubble-doctrine.md`
- `adr/cookie-domain-scope-by-surface.md`
