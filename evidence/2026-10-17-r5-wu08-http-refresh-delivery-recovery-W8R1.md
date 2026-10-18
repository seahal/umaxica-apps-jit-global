# R5-WU08 HTTP Refresh and exact delivery recovery

Date: 2026-10-17 UTC. HEAD `17903f7d121aa33efe29f2db9235c9aa5db4b001`; uncommitted worktree.

## OP side

- `OidcRefreshDeliveryReceipt` version 2 binds `attempt_ref` (nil for in-process OP reissue; a
  nil-bound receipt is never matched by a query). Five-second TTL unchanged; no v1 reader kept.
- Token endpoint accepts `attempt_ref`; `OidcTokenExchangeCoordinator` → `OidcRefreshTokenIssuer`
  records it in the receipt.
- `OidcRefreshTokenIssuer#query_delivery`: read-only, actor guard first, then grant lock; answers
  only a `:ready` receipt whose predecessor and attempt match; never rotates or extends.
- `OidcRefreshDeliveryQuery` + `POST /oauth/refresh-deliveries/query` on Base app/com/org
  (private_key_jwt bound to that URL, rate-limited, no-store). Shared epoch rule extracted to
  `AuthenticationEpochValue.root_current?`.

## RP side

- `RpRefreshCommitter`: reserve attempt under session lock (HMAC of the credential, expected
  generation, 5s expiry) → commit → `OidcOpTokenClient.refresh(attempt_ref:)` → on indeterminate,
  one `query_delivery` for the same attempt → verify Access JWT (public JWKS, sid) → re-lock
  session + OP binding and install only if live, unrevoked and generation unchanged.
- `OidcOpTokenClient.query_delivery` added; test transport routes the query path in-process.

## Results

- `RpRefreshCommitterTest` 9 runs: install, attempt ref sent, refused/dependency/invalid_remote,
  indeterminate→query install, indeterminate→query refused, superseded, revoked during dispatch,
  revoked before dispatch, foreign sid.
- Token exchange + receipt + tooling tests: 176 runs, 0 failures (query returns exact rotation,
  refuses other/blank attempt, refuses after the OP-clock window, refuses failed assertion and a
  stopped actor).
- Not done: RP controllers still refresh through `BrowserRpAuthentication` (OP-grant cookies);
  wiring `RpRefreshCommitter` follows the WU07 controller switch. Budget measurements (2s/1s/4s
  targets) not performed.
