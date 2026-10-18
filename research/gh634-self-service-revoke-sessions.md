# GH-634: Self-Service Revoke Other Sessions

## Status

Accepted implementation note for the sign session-management track.

## Scope

This note records the final state of the self-service revoke-other-sessions flow.

## Implemented behavior

- `sign/app`, `sign/org`, and `sign/com` configuration session screens expose an `others` action.
- The current session is protected from batch revoke.
- Empty revoke selections are rejected in the sign-in session flow.
- Already-revoked sessions are ignored safely.

## UX and copy

- App and org session screens use surface-specific session-management copy.
- Com session management uses the same revoke safety rules and redirects.

## Verification

- Regression tests cover current-session protection and no-op revoke paths.
- The Rails test harness still has a separate existing `i18n_locale_reset` / document schema issue
  that blocks full `rails test` runs in this workspace.
