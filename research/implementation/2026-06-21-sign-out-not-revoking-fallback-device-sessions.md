# Sign-Out Did Not Revoke Fallback Device Sessions

## Status

Fixed. Ordinary sign-out silently failed to revoke sessions whose device session had no
`current_refresh_token` (fallback / non-DBSC sessions), leaving the user signed in after sign-out.

## Symptom

After confirming sign-out (`POST /sign/out`), the user was still authenticated: auth-required pages
opened, name/avatar persisted, and the state survived reload and new tabs. Observed with email
sign-in. This was a real server-side session survival, not browser caching.

## Root Cause

1. `DeviceSessionable#revoke!` performs `update!(...)`, which re-runs model validations. The
   device-session models declared `belongs_to :current_refresh_token` **without** `optional: true`,
   so Rails required it. The column is nullable in the schema and is legitimately blank for fallback
   (non-DBSC) sessions and before the first refresh rotation. For such sessions `revoke!` raised
   `ActiveRecord::RecordInvalid` ("current refresh token can't be blank").
2. `AuthenticationLogoutCurrentSession#revoke_device_session!` rescued that `RecordInvalid` (and
   friends), logged at `info`, and returned `true`. Because the caller skips the direct token revoke
   when a device session is present (`device_session_cascade_handles_token?`), the session token was
   never revoked. Per-request resolution (`AuthenticationCurrentResourceResolver`) re-checks
   revocation against the primary DB, so the still-usable token kept resolving the user -> "signed
   out but still signed in".

This is the AGENTS.md no-silent-fallback anti-pattern: a swallowed validation error hid a complete
sign-out failure.

## Why only some sign-ins

Sessions whose device session already had a `current_refresh_token` (e.g. after a refresh rotation,
or DBSC-bound sessions) revoked fine. Fallback sessions (no DBSC, no current refresh token) were the
broken case.

## Fix

- `Client/Operator/VisitorDeviceSession`: `belongs_to :current_refresh_token, optional: true`,
  consistent with the nullable column. Revocation must always succeed regardless of refresh-token
  state.
- `AuthenticationLogoutCurrentSession#revoke_device_session!`: raised the log level to `warn` and,
  on a caught error, now revokes the session token directly (`revoke_token!(token_record)`) so a
  device-session revoke failure can never leave the current session usable. Defense-in-depth; the
  model fix removes the trigger.

## Tests

`test/controllers/concerns/authentication/logout_resolver_round_trip_test.rb`:

- Resolver round-trip: sign in -> logout -> the access token no longer resolves a resource. Failed
  before the fix (resource still resolved).
- Fallback device session (no `current_refresh_token_id`) is revoked by current-session logout,
  along with its token.

## Follow-up Risk

The token revoke being gated solely on the device-session cascade
(`device_session_cascade_handles_token?`) is fragile: any future failure in the cascade path would
again rely on the rescue fallback added here. Consider always revoking the resolved session token in
addition to the cascade.
