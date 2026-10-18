# Step 11 — Authentication-path and expiry audit

Recorded against full commit `68104a73d18c4a0eeaacb528c84ed515ab0bc989` on branch `feature`. The
worktree contained extensive unrelated edits plus the Step 10 and Step 11 changes. No unrelated
files were included in this work. Verification used the standard Rails `test` databases only; no
isolated fleet, reset, migration, development database write, or production access was used.

The audit found two bearer-authentication paths that could read parent credentials from a replica:
OIDC Access JWT authentication and Palm Bearer authentication. Both now look up the parent on the
realm Ticket writer with query caching disabled. Browser RP admission already reads the RP session
on the writer with caching disabled and verifies its current Device Session and root token. OIDC
code exchange and refresh revalidate the current root before issuing or rotating credentials.
Ordinary acceptance now rejects missing or infinite root expiry and missing or infinite RP refresh
expiry; RP expiry must be no later than its root expiry. No historical row is rewritten and no
expiry is guessed.

| Current path                                        | Observed behavior and evidence                                                                                                                                                                                                                                                                                                                                                      |
| --------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Core, Warp, Edit, and Base Self-RP browser requests | Browser RP authentication re-reads the RP session on the writer without query caching, then checks the Device Session, current root and RP expiry. Parent revocation is refused on the next request. Safe and unsafe refresh checks retain the same live-parent gate; tests cover safe refresh and protected POST refusal.                                                          |
| Core, Warp, Edit, and Base Self-RP OIDC Access JWTs | `OidcAccessTokenAuthenticator` now reads the claimed Base root on its Ticket writer without query caching and checks that it is usable. A parent-revoked token is refused; revoking only the child RP session leaves the already-issued JWT independent while the parent remains active. The configured stateless access-token ceiling remains five minutes plus 30 seconds leeway. |
| IdP authorization-code exchange and refresh grant   | The current root is checked before code consumption and again during writer-side issuance/rotation. Tests verify an unbounded root cannot consume a code or extend refresh credentials, and parent revocation prevents refresh.                                                                                                                                                     |
| Palm Bearer API                                     | The parent ticket lookup now uses the writer without query caching. Tests verify refusal after parent revocation and for an infinite root expiry. The Palm native API itself remains scheduled for retirement in Step 13.                                                                                                                                                           |
| Long-lived connection and parent-independent grants | Repository inspection found no mounted Action Cable channel and no `offline_access` support in the current discovery/grant declarations. No long-lived authenticated channel was found.                                                                                                                                                                                             |
| Database failure                                    | Browser RP authentication handles Active Record failures as HTTP 503. OIDC and Palm authentication do not rescue a failed authoritative parent lookup into another source, so a database exception cannot produce an authenticated result. A live database outage was not induced in this run.                                                                                      |

Tech is not yet present and must be included in the planned Step 15 repeat audit. Step 12 remains
blocked by the previously recorded Step 6 prerequisite; no shared-database sign-out implementation
was attempted here. This evidence covers current authentication paths and does not claim completion
of the global sign-out invariant or the later Palm/Tech audits.

Verification performed:

- `PARALLEL_WORKERS=1 bin/rails test` over 21 targeted Jump and authentication-path files: 483 runs,
  2,731 assertions, 0 failures, 0 errors, 0 skips. The auth-path cases include actual parent
  revocation through `RpSessionRevoker`, browser safe/unsafe refresh refusal, OIDC code and refresh
  refusal for unbounded roots, and Base Self-RP resource resolution.
- `bundle exec rubocop` over the 33 changed Step 10/11 Ruby files: 33 inspected, no offenses.
- `git diff --check`: passed.
