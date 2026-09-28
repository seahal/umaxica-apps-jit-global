# Invalid Browser Credential Recovery

## Status

Accepted (2026-09-26). **Current normative contract** for refused auth and preference browser
credentials.

Supersedes: `adr/preference-credential-entry-recovery.md` (its GET cookie-retention rule, its
`rotation_failed` recovery, its `401` for `unclassified`, and its `detached_for_entry` outcome name).
The superseded record is kept for history; where the two disagree, this record governs.

## Principle

**INVALID CREDENTIAL MUST NOT BECOME A BROKEN SESSION, AND A SYSTEM FAILURE MUST NOT BECOME AN
INVALID CREDENTIAL.** A refused credential grants no authentication or preference authority. Its
refusal reason stays internal: it is not reflected in a status, redirect, response body, or public
header. Database, transaction, issuer, and resolver exceptions are not refusals; they propagate
through the ordinary error handling (a `5xx`) and never become an anonymous success.

## Failure taxonomy

Every refusal has one of three classes.

| Class | Meaning | Recovery |
| --- | --- | --- |
| Credential rejection | The presented credential itself is unusable. | Detach, continue anonymous |
| Lifecycle | A valid credential ended its life in the ordinary way. | Detach, continue anonymous |
| System failure | Verification itself failed, or no confirmed cause exists. | Raise; never detach |

Logs carry the class as `category` (`credential_rejection` or `lifecycle`), so an ordinary expiry is
not counted as a security signal.

### Auth (`AuthenticationBase::AUTH_CREDENTIAL_FAILURE_CATEGORIES`)

- Credential rejection: `token_decode_failed` (malformed, bad signature, expired JWT),
  `missing_session_id`, `token_session_not_found` (unknown or revoked session), `token_jti_mismatch`,
  `dpop_verification_failed`, `dpop_binding_mismatch`, `actor_mismatch`, `resource_not_found`,
  `invalid_format`, `token_not_found`, `invalid_digest`, `refresh_token_reuse_detected`,
  `binding_denied` (DPoP or DBSC refresh binding).
- Lifecycle: `idle_timeout`, `inactive_token` (expired or discarded refresh token).
- Not refusals: `withdrawal_required`, `administrative_access_locked`, and
  `administrative_access_token_stale` are policy states of a valid credential. Their gates need the
  credential, so the access cookie is not detached for them.
- A reason missing from the map raises `KeyError` when logged rather than receiving a guessed class.

### Preference (`PreferenceTransport::PREFERENCE_CREDENTIAL_FAILURE_CATEGORIES`)

- Credential rejection: `malformed`, `record_not_found`, `digest_mismatch`, `binding_denied`,
  `replay_detected`.
- Lifecycle: `ordinarily_deleted` (status `DELETED`, the ordinary user deletion; a clean context is
  the intended result), `expired_or_revoked` (`expires_at` aliases `discard_at`, which revocation and
  replay handling also set, so the schema cannot separate the two), `superseded_generation` (see
  Concurrency).
- `rotation_failed` is no longer a refusal. When rotation finds no consumable row, the row is read
  again on the writing role: a concurrent replay, expiry, revocation, or deletion is reported as that
  confirmed state; a row that is still valid raises `PreferenceBase::ResolutionError`. The
  `preference.token.refresh.rotation_failed` log event still records the attempt.
- `unclassified` (or no recorded cause) raises `PreferenceBase::ResolutionError` and logs
  `outcome: system_failure`. It is never detached.

A lookup that raises is not caught, so it is never reported as missing or expired, and the cookie is
not deleted. A cookie value with an invalid byte sequence is client input, not a system failure:
`BrowserCredentialCookie.read` replaces the invalid bytes, and the still-unparseable value is refused
as malformed.

## Auth

A refused access cookie is detached with the auth cookie deletion options, and the request continues
anonymous. A public HTML page renders, a protected HTML page takes the same redirect as a request
without the cookie, and JSON keeps its existing authentication failure response and does not detach the cookie
(the next HTML navigation does). A refused refresh cookie at
the refresh endpoint deletes the auth cookies with the `401 invalid_refresh_token` body shared by
every reason. Transparent refresh stays disabled on GET, so an HTML navigation never consumes the
refresh or DBSC cookie. Refresh reuse detection and family revocation are unchanged.

The Core browser JSON boundary answers every refused RP access cookie with the same
`authentication-required` problem document and deletes its RP cookie pair with the RP cookie
contract's deletion options.

## Preference

A refused preference credential on an HTML GET or HEAD, or on a declared sign-in/sign-up entry, is
detached: its cookies are deleted and the request renders from clean display defaults. JSON callers
and other writes keep the `401` contract. Detaching never creates, rotates, extends, or adopts a
preference, never writes the public option cookies, and never copies the old row's settings into a
new credential. The next explicit write bootstraps a fresh row through the existing creation
protocol, so a stream of random invalid cookies cannot create one row per GET.

## Concurrency

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

Deletions use the issuing options: the same name (`__Host-` prefix whenever
`JitSessionCookieConfig.force_secure?`), `Path=/`, host-only (no `Domain`), `Secure` as issued,
`SameSite=Strict`, and `Partitioned` in production. HttpOnly is not part of cookie identity, and a
server `Set-Cookie` may expire an HttpOnly cookie. Rails emits a deletion only for a cookie the
request carried. Host-only deletions cannot reach another surface's cookies.

## Observability

- `auth.credential_rejected`: `surface`, `credential_kind` (`access_cookie`, `refresh_cookie`,
  `dbsc_cookie`, `oidc_rp_access_cookie`), `reason`, `category`, `request_id`.
- `preference.credential.recovery`: `failure`, `category`, `binding_reason`, `stage`
  (`read_only_lookup`, `refresh_lookup`, `rotation`), `outcome` (`detached`,
  `detached_stale_generation`, `rejected`, `system_failure`), `surface`, `host`, `controller`,
  `action`, `request_method`, `request_id`.

Neither event carries a cookie value, token, verifier, digest, or secret. System failures appear only
as `system_failure` or as the raised exception, never under a refusal category.
