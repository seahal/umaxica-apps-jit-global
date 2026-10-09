# Device Session / DBSC / device_id Auth Reshape

Implemented a compatibility-first device session layer for auth tokens.

- `device_sessions.public_id` is the intended access-token `sid` for new sessions.
- `device_id` remains a cookie-originated compatibility identifier; only its digest is stored on
  `device_sessions`.
- DBSC binding is represented on the same `device_session` but remains distinct from `device_id`.
- Refresh rotation preserves `device_session_id` and advances `current_refresh_token_id`.
- Ordinary logout revokes the current `device_session` and tokens linked to it, not every actor
  token.

Remaining follow-up:

- Backfill old token rows into device sessions before making `device_session_id` non-null.
- Promote DBSC public-key material/verification from token rows to device sessions.
- Update session inventory UI to render device sessions directly instead of token rows.
