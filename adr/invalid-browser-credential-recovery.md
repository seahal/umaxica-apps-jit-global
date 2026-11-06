# Invalid Browser Credential Recovery

## Status

Accepted (2026-09-26); amended 2026-10-31 under the owner-approved Preference design. **Current
normative contract** for refused auth and Preference browser credentials.

Supersedes: `adr/preference-credential-entry-recovery.md` (its GET cookie-retention rule, its
`rotation_failed` recovery, its `401` for `unclassified`, and its `detached_for_entry` outcome
name). The superseded record is kept for history; where the two disagree, this record governs.

## Principle

The `auth_*` / `feel_*` naming preserves the GET refresh prohibition. Reading validated access and
detaching/deleting confirmed invalid or expired cookies on GET are distinct from consuming
`auth_refresh` or `feel_refresh` to issue new access credentials. Recovery creates no GET refresh
exception and retains each endpoint's refusal and concurrency rules. TanStack's zero-cookie UI
origin never performs these Rails recovery operations; see
`adr/tanstack-start-zero-cookie-ui-origin-boundary.md`.

**INVALID CREDENTIAL MUST NOT BECOME A BROKEN SESSION, AND A SYSTEM FAILURE MUST NOT BECOME AN
INVALID CREDENTIAL.** A refused credential grants no authentication or preference authority. Its
refusal reason stays internal: it is not reflected in a status, redirect, response body, or public
header. Database, transaction, issuer, and resolver exceptions are not refusals; they propagate
through the ordinary error handling (a `5xx`) and never become an anonymous success.

## Failure taxonomy

Every refusal has one of three classes.

| Class                | Meaning                                                   | Recovery                   |
| -------------------- | --------------------------------------------------------- | -------------------------- |
| Credential rejection | The presented credential itself is unusable.              | Detach, continue anonymous |
| Lifecycle            | A valid credential ended its life in the ordinary way.    | Detach, continue anonymous |
| System failure       | Verification itself failed, or no confirmed cause exists. | Raise; never detach        |

Logs carry the class as `category` (`credential_rejection` or `lifecycle`), so an ordinary expiry is
not counted as a security signal.

### Auth (`AuthenticationBase::AUTH_CREDENTIAL_FAILURE_CATEGORIES`)

- Credential rejection: `token_decode_failed` (malformed, bad signature, expired JWT),
  `missing_session_id`, `token_session_not_found` (unknown or revoked session),
  `token_jti_mismatch`, `dpop_verification_failed`, `dpop_binding_mismatch`, `actor_mismatch`,
  `resource_not_found`, `invalid_format`, `token_not_found`, `invalid_digest`,
  `refresh_token_reuse_detected`, `binding_denied` (DPoP or DBSC refresh binding).
- Lifecycle: `idle_timeout`, `inactive_token` (expired or discarded refresh token).
- Not refusals: `withdrawal_required`, `administrative_access_locked`, and
  `administrative_access_token_stale` are policy states of a valid credential. Their gates need the
  credential, so the access cookie is not detached for them.
- A reason missing from the map raises `KeyError` when logged rather than receiving a guessed class.

Preference credentials are realm-scoped signed JWTs. Their authority and cookie lifecycle are
defined by
[`preference-realm-jwt-and-host-bound-browser-binding.md`](preference-realm-jwt-and-host-bound-browser-binding.md)
and `two.md` §4. A refused Preference JWT is never treated as authentication or consent authority.
Preference credential refusal does not use the Auth refusal taxonomy or its cookie-detachment
middleware.

## Auth

A refused access cookie is detached with the auth cookie deletion options, and the request continues
anonymous. A public HTML page renders, a protected HTML page takes the same redirect as a request
without the cookie, and JSON keeps its existing authentication failure response and does not detach
the cookie (the next HTML navigation does). A refused refresh cookie at the refresh endpoint deletes
the auth cookies with the `401 invalid_refresh_token` body shared by every reason. Transparent
refresh stays disabled on GET, so an HTML navigation never consumes the refresh or DBSC cookie.
Refresh reuse detection and family revocation are unchanged.

A confirmed access-cookie detachment survives a later boundary refusal. When the request then ends
in an exception response (for example the Home/Dashboard 404 of
`adr/home-dashboard-authentication-boundary.md`), the exception renderer replaces the controller
response and the cookie jar is never written. `CredentialDeletionFinalizer`, a Rack middleware
outside the exception renderers, appends only the deletions registered after a
`credential_rejection` or `lifecycle` refusal, and only for a cookie that has no Set-Cookie in the
final response. It never flushes the cookie jar: issuance, rotation, session extension, and
preference cookies prepared by a failed request are not committed by an exception response. System
failures, JSON responses, and Preference refusals register nothing.

The Core browser JSON boundary answers every refused RP access cookie with the same
`authentication-required` problem document and deletes only the refused RP access cookie with the RP
contract's deletion options. The independent RP refresh cookie is retained without being read as
authentication evidence, consumed or rotated.

Amended 2026-10-04 for the integrated Core continuity requirement: the previous RP cookie-pair
deletion rule is superseded for access refusal. An access rejection, including ordinary JWT expiry,
does not establish that the refresh credential is invalid. Deleting it here prevented the existing
explicit POST from verifying a still-valid credential. The POST's existing CSRF, Origin, rotation,
replay and session-lifecycle checks retain authority; no transparent GET renewal, new endpoint,
browser retry protocol or grace period is introduced. Malformed access, wrong binding and
unavailable principals still receive the same refusal, with no actor data or new public reason. Root
auth, preference and explicit logout rules above are unchanged. See the
[Core request boundary](../docs/security/core-browser-request-boundary.md).

## Preference

A refused Preference JWT on GET or HEAD renders default display values without creating, retiring,
rotating, extending, or repairing a row. Base and Visa may delete their own invalid shared
Preference cookies; read-only hosts do not issue or delete shared cookies. A Base `save` with a
refused or missing JWT never changes the named row; it creates a defaults row and applies only valid
explicit request values, or returns a dependency failure if it cannot commit and issue the
replacement. Visa `sign_in`, `sign_out`, and Base `reset` follow their separate actor-snapshot,
database-copy, and retire-then-create rules in `two.md` §4.4; a refused JWT never authorizes
mutation of its named row or supplies copied state. A valid but stale `jti` remains displayable
through `exp` but does not authorize writes. Preference failure handling is separate from Auth
cookie detachment: a persistence, signing, or transaction failure is not an invalid credential and
cannot be reported as a successful save.

## Retired Preference concurrency contract

The following generation-rotation contract was removed with Preference refresh/DBSC state and is
retained here only as historical rationale. It is not normative for current Preference behavior.

GET and HEAD never rotate, so any number of reads of one generation succeed together.

A write that presents generation N without an access token rotates it to N+1. A read that left the
browser with N before that response arrived finds N consumed. When N was superseded by ordinary
rotation (`used_at` and `replaced_by_id` set, `discard_at` still in the future) within
`PREFERENCE_STALE_GENERATION_WINDOW` (one minute), the read is classified `superseded_generation`:
it renders defaults and emits **no** cookie deletion, because the browser may already hold N+1 under
the same cookie names. Whichever response the browser applies last, it keeps N+1. After the window,
the same credential is `replay_detected` and deleted, so recovery ends. Replay handling and sign-out
retirement set `discard_at` to now, so a compromised or retired row is never treated as a stale
generation.

Writes remain serialized. A second write presenting an already rotated generation is a replay: it is
refused with `401`, the replayed row is retired, and the newer generation is not revoked. There is
no grace window or replacement adoption for writes.

## Cookies

Authentication-cookie deletion uses the exact host-only cookie name, path, secure, and same-site
attributes used at issuance; it never clears another surface's credential. `Partitioned` is not
used. Preference cookies have a separate scope: the realm JWT and display cookies use that realm's
shared cookie domain, while the browser-binding cookie is host-only. Only an authorized Base or Visa
response may issue or delete that realm's shared Preference cookies, and Base alone owns the
host-only binding cookie.

## Observability

- `auth.credential_rejected`: `surface`, `credential_kind` (`access_cookie`, `refresh_cookie`,
  `dbsc_cookie`, `oidc_rp_access_cookie`), `reason`, `category`, `request_id`. The event carries no
  cookie value, token, verifier, digest, or secret. Preference refusal logging is owned by the
  applicable Preference boundary; this ADR does not define a refresh or rotation event.
