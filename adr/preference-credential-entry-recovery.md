# Preference Credential Entry Recovery

## Status

Superseded (2026-09-26) by `adr/invalid-browser-credential-recovery.md`, which is the current
normative contract. This record is kept for history. Its failure classification, GET cookie
retention, `rotation_failed` recovery, `401` for `unclassified`, and `detached_for_entry` outcome no
longer describe current behavior.

Originally accepted (2026-09-26).

## Context

A browser that kept an unusable preference refresh cookie could not sign in or sign up on the first
try. On an HTML GET, `PreferenceTransport#set_preferences_cookie` found no valid record and answered
with an empty `401` while keeping the cookie, so every later entry GET failed the same way. The first
POST (for example the admission continuation form or the Base "start" POST) also answered `401` but
cleared the cookie. The retry then succeeded, which matched the reported symptom that the first
operation fails and the second works.

This was reproduced on 2026-09-26 against `e423890e7` with uncommitted worktree changes, using
integration tests on the `app`, `com`, and `org` Auth and Base hosts in the test environment. The
production environment and the logs of the original incident were not available, so the reason each
affected browser's credential became unusable (reseeded database, ordinary expiry, replay) is not
established. The fix does not depend on that reason.

The preference credential carries display settings only. The Auth controllers do not include
`PreferenceAdoption`, and no admission, authentication, authorization, organization, OIDC, or
redirect decision reads `@preferences` or the preference JWT. Consent shown to a signed-in principal
comes from that principal's own stored preference (`ActorSupport#resolved_current_cookie`), not from
the browser credential.

## Decision

### Failure classification

A refused refresh credential records one reason on the request:
`malformed`, `record_not_found`, `digest_mismatch`, `binding_denied` (with the DBSC sub-reason
`dbsc_not_active`, `missing_bound_cookie`, or `session_id_mismatch`), `replay_detected`,
`ordinarily_deleted`, `expired_or_revoked`, `rotation_failed`, or `unclassified`.

`expires_at` is an alias of `discard_at`, which revocation and replay handling also set, so the schema
cannot separate an ordinary expiry from a revocation; the combined name records exactly that.

Only states the database positively confirmed are named. A lookup that raises (database or connection
failure) is not caught, so it is never reported as missing or expired, and the cookie is not deleted.

### Endpoint contract

| Endpoint | Unusable credential |
| --- | --- |
| Declared entry, HTML (`preference_entry_recovery_action?` is true) | Detach and continue |
| Same entry, JSON | `401` with `error_code: invalid_refresh_token` (unchanged) |
| Preference screens and writes, DBSC, other controllers | `401` (unchanged) |
| Any endpoint, `unclassified` failure | `401` |

Declared entries are every action on the `app`, `com`, and `org` Auth `ApplicationController`
hierarchies (ceremony screens and steps, including the `org` sign-up guide) and the `create` action of
the Base `RootsController` on each surface (the sign-in/sign-up start POST).

Detaching drops `@preferences` and `@preference_payload` and marks the request so
`load_access_token_payload` does not re-read the cookies. The rest of the request renders display
defaults. `set_color_theme` does not write the public option cookies from those defaults, and
`ensure_preferences_record` returns nil instead of creating a replacement record after a refusal.
Every other filter still runs: Jump return verification, rate limit, CSRF, admission, the logged-in
refusal, the withdrawal and restricted-session guards, and session limits.

### Side effects

A GET or HEAD entry never creates, rotates, extends, or adopts a preference, and does not delete
cookies. That keeps the existing rule that cleanup belongs to a write boundary.

A POST entry keeps the existing refusal side effects. A replayed credential is still marked revoked
and the preference auth cookies are still deleted. It does not create a replacement preference in
that request. A later request without the cookie bootstraps a fresh record through the ordinary path.
No state is inherited from the refused credential.

### Observability

Each refusal logs `preference.credential.recovery` with `failure`, `binding_reason`, `stage`
(`read_only_lookup`, `refresh_lookup`, `rotation`), `outcome` (`detached_for_entry` or `rejected`),
`surface`, `host`, `controller`, `action`, `request_method`, and `request_id`. The existing
`preference.token.refresh.*` events are unchanged. A rise in `record_not_found` still shows up in the
logs even though the entry no longer stops the visitor.

## Unchanged

- Authentication refresh-token rotation, reuse detection, and family revocation.
- Preference refresh rotation and replay handling on write endpoints. The replay grace behavior is not
  extended.
- Cookie names, scopes, and attributes (`__Host-` prefix, `SameSite=Strict`, `HttpOnly`, `Secure`).
- Admission issue and consume points, and the admission continuation POST.
- The `401` contract for JSON and preference endpoints.

## Consequences

A stale preference credential no longer blocks the sign-in and sign-up entries on any surface, and it
grants nothing. A credential kept on GET is detached again on each entry GET until the first entry
POST retires it. That repeated lookup costs one indexed read per GET.
