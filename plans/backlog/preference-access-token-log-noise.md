# Preference Access Token Log Noise

## Status

Backlog. Not scheduled. Diagnosis and supporting observations:
`evidence/2026-10-07-preference-invalid-access-token-log-K4W7.md`.

## Problem

`PreferenceWebCookieEndpoint#decode_and_verify_preference_jwt` logs
`errors.preference.cookie.invalid_access_token` at `info` level whenever no access token payload is
available. A browser that never held a preference cookie and a browser presenting an undecodable
one produce the same line, so the cookie banner endpoint (`GET /api/v0/preferences/cookie`) emits it
for every anonymous visitor. The line reads like a fault while describing the ordinary state, and it
hides the case that is worth seeing.

## Proposed change

1. Emit nothing when no access cookie is presented. That is the normal anonymous state.
2. When a cookie is presented but does not decode, emit a structured `JitLogEvent` in the existing
   `preference.credential.recovery` vocabulary instead of a translated sentence, so it can be
   counted alongside the other credential refusals. Keep the token and its claims out of the event.
3. Remove the `errors.preference.cookie.invalid_access_token` key from every locale bundle once
   nothing reads it.

## Open question

The banner endpoint skips `set_preferences_cookie`, so a stale preference cookie stays in the
browser until an HTML read detaches it, and the endpoint reports on it at every call in between.
Decide whether the endpoint should run the read-only detach step itself. Any answer must keep the
GET refresh prohibition in `adr/invalid-browser-credential-recovery.md`: a read may delete a
confirmed-unusable cookie, and must not create, rotate, or issue a preference credential.

## Out of scope

Restoring reissue on GET. Its removal is the accepted contract, not a regression.
