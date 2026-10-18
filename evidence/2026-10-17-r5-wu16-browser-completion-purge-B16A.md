# R5-WU16 browser completion and cookie purge; WU09 entry delegation

Date: 2026-10-17 UTC. HEAD `17903f7d121aa33efe29f2db9235c9aa5db4b001`; uncommitted worktree.

- WU09 delegation: the surviving RP-initiated logout authority (`OidcRpLogoutAuthority`) now passes
  a `within_commit` hook to `AuthenticationLogoutCurrentSession`, which runs `OpLogoutCommitter` in
  the same OP transaction as the revocation (idempotency key = durable logout challenge). The
  browser receives the one-time receipt nonce in its session only.
- Base `GET/POST /sign/bye` on app/com/org (`BaseSignBye`): GET reads OP-established outcome and
  pending/completed RP notifications without changing state; POST consumes the receipt once (nonce
  digest, expiry, consumed_at under lock).
- RP `POST /sign/out/purge` on all 12 cells (`RpCookiePurgeEndpoint`): clears RP cookies only when
  the presented credential names the requested sid and the cell holds that sid's tombstone.
- DBSC: unchanged; the OP DBSC authority keeps its server-side checks (no RP access to OP internals
  added).

Results

- Logout suites (7 files incl. authority-first, completion matrix, sibling scope, partitions, Base
  logouts): 134 runs green; authority-first now also asserts the realm flow, participants and
  unconsumed receipt.
- `Base::App::SignByesControllerTest` 4 runs, `RpCookiePurgeTest` 3 runs: green.
