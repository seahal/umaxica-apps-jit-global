# Step 11 — Authentication-path audit after Palm and Tech

Recorded 2026-10-14 against full commit `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5` on branch
`feature`. The worktree was extensively dirty. Verification used only the standard Rails test
databases; the isolated-run ID was unset. The frozen plan files remain unchanged.

This follow-up extends the earlier Step 11 record at
`evidence/2026-10-13-auth-path-step11-S2A4.md` to include the now-present Palm and Tech browser RPs.
The common `BrowserRpAuthentication` boundary covers Core, Warp, Edit, Base Self-RP, Palm and Tech:
it reads the RP row and current parent state from the writer without query caching, refuses a
revoked or changed parent on the next request, and clears RP browser cookies on authentication
refusal. Its safe refresh path retains the same parent check. Unsafe refresh is gated by request
provenance and Rails authenticity-token verification before refresh or mutation.

| Path | Current behavior and observed coverage |
| --- | --- |
| Core, Warp, Edit, Base Self-RP, Palm and Tech browser requests | Shared Browser RP authentication checks current RP, Device Session and root state on the writer. Tests cover parent and child revocation, stale root binding, refusal and cookie clearing. Surface-specific Palm and Tech dashboard and callback tests pass. |
| Safe and unsafe browser refresh | A safe request cannot rotate credentials after parent revocation. Unsafe requests reject untrusted provenance and require the Rails authenticity token before refresh or mutation. The focused Browser RP suite passed. |
| IdP code exchange and refresh/reissue | The current root is checked before code consumption and during writer-side issuance or refresh rotation. Tests cover inactive or unbounded roots, refusal to extend beyond root expiry, and refresh refusal after parent revocation. |
| OIDC Access JWT and userinfo | The Base root is read from the Ticket writer without query caching. A revoked parent makes the JWT fail authentication; revoking only its child RP row leaves the stateless JWT valid while the parent remains active. The configured ceiling is five minutes plus 30 seconds leeway. |
| Palm API/Bearer path | Palm native clients and their Bearer/API path have been retired. Registration and old-code/refresh tests reject the retired clients; browser authentication uses the common cookie RP contract. No Bearer-to-cookie bridge remains. |
| Tech grant and browser path | Tech admission checks the current `tech.access` grant. A protected dashboard request without a current grant receives no-store 403; token refresh after grant revocation is refused without rotating the RP credential. Tech sign-out remains available after the grant is revoked. |
| Long-lived authenticated connections and parent-independent grants | Repository inspection found no mounted Action Cable channel and no `offline_access` grant. No authenticated long-lived channel or parent-independent OIDC grant was found. |
| Replica/cache reads and database failure | Live Browser RP, OIDC Access JWT and token-exchange parent checks use writer-side reads with query caching disabled. Browser RP database dependency failures return HTTP 503 and do not admit the request. A live database outage was not induced; OIDC failure was verified by code-path inspection and no fallback source was found. |

The effective OIDC Access JWT lifetime is five minutes with 30 seconds verifier leeway. Operator
root absolute lifetime and refresh cap are eight hours; Operator idle expiry is 30 minutes and
activity writes are throttled to at most one per 60 seconds. RP access and refresh cookie expiries
are derived from the token endpoint's `expires_in` and `refresh_token_expires_in` values. Writer-side
issuance and refresh tests ensure RP expiry does not exceed root absolute expiry. These are
configured and behavior-tested limits, not a claim that a live browser was left open until each
boundary.

The focused post-Palm/Tech selection passed: 196 runs, 881 assertions, 0 failures, 0 errors and
0 skips. It included Browser RP refusal/refresh/database-failure cases, OIDC token exchange and
Access JWT cases, session absolute-expiry cases, Palm browser/retirement cases, and Tech dashboard,
callback, sign-in, sign-out and post-revocation refresh cases. The full standard Rails run also
completed but was non-clean (15,256 runs, 128,991 assertions, 1 failure and 14 Avatar receipt-guard
errors); details are recorded in
`evidence/2026-10-14-frozen-string-directives-followup-Q3M7.md`. `git diff --check` passed.

No live database outage, real-browser session, external API client or long-lived connection was
exercised. This audit covers authentication-path behavior and does not claim the blocked shared
transactional sign-out or global wording invariant is complete.
