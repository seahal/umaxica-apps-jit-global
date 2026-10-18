# R5-WU09 OP logout commit owner and R5-WU10 outbox sender / RP back-channel receiver

Date: 2026-10-17 UTC. HEAD `17903f7d121aa33efe29f2db9235c9aa5db4b001`; uncommitted worktree.

## WU09

- `OpLogoutCommitter`: one realm-OP transaction locks the device session and root, revokes the root
  and every grant under it, records LogoutFlow (op_revoked_at), one Participant per grant (frozen
  BCL endpoint from `OidcClientStoresStaticClientStore.backchannel_logout_uri`), a one-time
  browser-bound LogoutReceipt (nonce digest) and one OutboxEvent per participant. Idempotent on
  (realm, idempotency digest): a retry rereads the committed flow.
- Not done: existing sign-out entry routes/coordinators (`AcmeLogoutTransactionCoordinator`, Base
  `/sign/bye`) are not yet delegating to this committer; the browser receipt consumption and per-RP
  cookie-purge endpoints are not implemented.

## WU10

- OP: `OpLogoutTokenIssuer` (ES384 realm OP key, `logout+jwt`, exact aud/sid, BCL event, no nonce,
  2-minute lifetime); `OidcBackchannelLogoutClient` (no redirects, only 200 acknowledges);
  `OpOutboxDispatchJob` (short lease tx with SKIP LOCKED → delivery outside any tx → short outcome
  tx; exponential backoff; expired leases recovered).
- RP: `OidcOpLogoutTokenVerifier` (strict; rejects nonce, missing event, wrong aud/iss/typ/key);
  `RpCellSessionRevoker` (receipt by JTI digest + upsert/lock per-sid anchor + absorbing tombstone +
  session revocation in one cell tx; duplicate = success; unknown sid tombstoned);
  `POST /oidc/backchannel-logout` on all 12 RP cells via `RpBackchannelLogoutEndpoint`.
- Note: an earlier draft accidentally overwrote the existing OP-side `RpSessionRevoker`; it was
  restored from the index (which held the R3 rename) and the receiver was renamed
  `RpCellSessionRevoker`. Any unstaged edits to that file that were not in the index could not be
  recovered; none were known.

## Results

- `OpLogoutCommitterTest` 4, `RpCellSessionRevokerTest` 4, `OpOutboxDispatchJobTest` 5,
  `RpBackchannelLogoutReceiverTest` 3 (end-to-end OP sign → RP endpoint verify via in-process
  published JWKS → tombstone, duplicate 200, bad token 400): all pass. RuboCop clean.
- Not done: scheduler wiring for `OpOutboxDispatchJob`; full suite not re-run for this packet.
