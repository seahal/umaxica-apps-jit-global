# RP-session issuance boundary verification

- Date: 2026-09-18 UTC
- Branch: `feature`
- Commit before this slice: `92c4cdba2`
- Existing unrelated working-tree changes were preserved and not staged.

## Finding and implementation

The refresh flow commits refresh-token rotation before the coordinator encodes the refreshed Access
JWT. A concurrent RP-session revoke could therefore win between those operations unless the final
Access JWT-expiry recording rechecked the session under the same lock order. The implementation now
locks the Base Browser Session first, then the RP Session, rechecks `active?`, and raises
`RpSession::IssuanceRejected` when the session or parent is no longer active. The OIDC coordinator
returns `invalid_grant` without returning an Access JWT. It does not restore a consumed refresh
token.

## Checks

- `test/models/rp_session_test.rb` passed: 22 runs / 118 assertions / 0 failures / 0 errors / 0
  skips. The new regression covers client, operator, and visitor RP sessions after revoke.
- The existing `RpSessionRevoker` lock-order test remains the companion check that revocation locks
  the parent before the child.
- Syntax and RuboCop checks over the changed production/test files passed.
- Authorization-code exchange and refresh integration execution remains limited by the unavailable
  isolated Valkey service; no external or production service was used.

## Boundary retained

PostgreSQL RP-session revocation still does not retroactively invalidate an already returned Access
JWT. The configured verifier expiry and clock-skew window remain the residual natural-expiry period.
