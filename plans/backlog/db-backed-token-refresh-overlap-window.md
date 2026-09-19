# DB-Backed Token Refresh Overlap Window

## Status

Backlog. Deferred on 2026-05-19.

## Context

`plans/active/token-rotation-concurrency-hardening.md` improved the safety baseline for auth and
preference token rotation, but intentionally did not implement a legitimate parallel-refresh overlap
window.

The remaining problem is the high-throughput case where multiple legitimate requests present the
same refresh token close together because of browser concurrency, retry, or a lost response. Redis /
Valkey must not be used for this session-management path.

## Goal

Add a DB-only overlap mechanism that:

- keeps refresh-token replay detection strict;
- avoids abnormal user-visible failures for legitimate near-simultaneous retries;
- uses PostgreSQL row locks and persisted token state only;
- works for both auth tokens and preference tokens through the shared rotation contract.

## Non-Goals

- No Redis, Valkey, Solid Cache, or external distributed lock.
- No client-side coordination requirement.
- No long-lived access-token overlap beyond normal access-token TTL.
- No weakening of replay / compromise handling outside the overlap window.

## Target Behavior

When request A rotates generation N to N+1, a near-simultaneous request B presenting generation N
may be treated as a benign retry only if all conditions are true:

- same token family;
- same device / binding;
- generation N points to generation N+1 as successor;
- generation N was consumed inside the short overlap window;
- generation N+1 is active and not revoked / compromised.

If any condition fails, classify the request as replay / compromise according to the auth or
preference policy.

## Candidate Implementation

Use existing state where possible:

- auth already has `refresh_token_family_id`, `refresh_token_generation`, and `rotated_at`;
- preference already has `used_at` and `replaced_by_id`;
- both paths now share digest-row locking and device-id matching through `RefreshTokenShared`.

Possible additions if existing columns are insufficient:

- successor id for auth token rows;
- explicit overlap expiration timestamp;
- generation/family columns for preference rows if needed for older-generation detection.

## Required Tests

- Auth: two parallel uses of the same refresh token result in one rotation and one accepted overlap
  response, or one deterministic replay if the feature is disabled.
- Auth: generation N-2 reuse revokes even if N-1 is inside overlap.
- Auth: same token with different device / binding revokes.
- Auth: revoked successor never gets returned as an overlap response.
- Preference: same matrix as auth.
- No raw refresh token, verifier, cookie, or authorization header is logged.

## Current Solved Portion

Already done in the active plan:

- Redis/JTI-deduplication direction deprecated.
- Common DB row-lock primitive added to `RefreshTokenShared`.
- Auth and preference rotation use the shared lock/device helpers.
- Preference access-token `jti` is checked against the current DB row.
- Security-intent tests cover stale `jti`, missing `jti`, invalid verifier without actor revoke,
  device mismatch without consumption, and replay precedence over device mismatch.

## Related

- `docs/security/refresh-token-rotation.md`
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
