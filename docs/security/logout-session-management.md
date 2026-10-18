# Logout And Session Management

> **Current first-party status (2026-10-15):** The accepted current contract is
> `adr/first-party-sign-out-shared-database-without-backchannel-logout.md`. The older Acme/Sign
> ownership and `/sign/out/complete` descriptions below are retained as migration history. The
> all-12 completion continuation matrix now covers challenge GET, token-bearing POST and one-shot
> completion after parent/RP revocation. The shared parent-and-RP revocation transaction is locally
> implemented and focused-tested. Local authority-first HTTP tests and an independent-connection
> sign-out/refresh race pass. First-party BCL has been removed: no sender, receiver, client
> declaration or discovery claim remains. The complete all-RP authority-flow matrix and real browser
> acceptance remain open.

## Browser RP logout implementation

The accepted Browser RP sign-out flow starts at the surface's protected `POST /sign/out`, uses
Base's `/oidc/logout` authority flow and returns to the initiating surface with a durable logout
challenge. Every registered first-party Browser RP registers exact `post_logout_redirect_uri` values
for `GET/POST /sign/out/completion?ri=jp` and `?ri=us` on its own host; direct `/sign/out` is
rejected as a return URI. GET displays the continuation without advancing it; POST validates the
Rails authenticity token and advances cleanup. Base/Auth unsafe requests require the token even for
same-origin requests. The challenge continuation has no DELETE cancellation route. Core, Warp, Edit
and Base reuse their surface-local sign-out controller; Palm and Tech keep their dedicated
completion controllers. Tech sign-out does not require `tech.access`, so revoking that capability
does not prevent a correctly authenticated logout.

Every unsafe completion continuation requires a same-session Rails authenticity token, even when
Fetch Metadata says same-origin. The token is additional to the captured browser intent proof.
Missing or mismatched proof and invalid tokens preserve the transaction; unavailable continuations
return 422 in every realm, and JSON CSRF failures return 403. The continuation boundary sends
`no-store` for challenge pages and refusal responses. GET preserves all persisted transaction
fields, including timestamps. The twelve-client local matrix exercises these partitions and both
present and absent Fetch Metadata; see
[token verification](../../evidence/2026-10-15-completion-token-required-C8S4.md),
[immutable GET and Origin checks](../../evidence/2026-10-15-completion-origin-get-invariants-F9B2.md),
and [Fetch Metadata verification](../../evidence/2026-10-15-completion-fetch-metadata-N3Q6.md).

Every display after the authority step is derived from the parent Device Session on the realm Ticket
writer (`AcmeLogoutTransactionCoordinator.parent_revoked?`), never from the AppTicket progress
record:

- revoked parent and finished cleanup: the global completion wording, which states no end time;
- revoked parent and a failed origin cleanup or progress write, at Base or at the origin: the same
  completion page with the "cleanup incomplete" wording and `200`, never "not completed" or `404`;
- unreadable parent or a lost COMMIT response: the indeterminate page, `503`, with no retry button;
- parent still active: the existing refusal (`422` at the origin, `404` at Base).

Base re-checks the authority and the root binding inside the revoking transaction after locking the
parent Device Session; a binding that no longer holds stops with the IdP session error and revokes
nothing.

Base stages a logout intent only after confirming a live IdP session and its captured `sid`. A
missing session, missing `sid`, or mismatched `id_token_hint` is a plain localized no-store error;
the request has no redirect and changes no session, token, or intent state.

The completion matrix covers all 12 first-party client IDs after same-realm parent and RP-session
revocation, including HTML and Inertia responses at `ri=jp`. It does not establish the full IdP
authority flow or real browser behavior, and it does not establish that the shared-database global
sign-out contract is complete. The all-client route, registration and integration matrix is recorded
in `evidence/2026-10-13-first-party-rp-completion-uri-matrix-P7V4.md`; earlier Palm and Tech cleanup
tests are recorded in `evidence/2026-10-13-palm-completion-route-followup-J3K7.md` and
`evidence/2026-10-13-tech-palm-browser-rp-logout-M5Q8.md`.

## Authority

Logout is session mutation. `acme/www` owns logout, session revoke, revoke-all, session listing,
historical status-103 handling, device/session display, token-family revocation, and compromise
state.

`sign/id`, `core`, and `base` must not mutate authoritative acme logout or session state. They may
host the surface-local browser ceremony (`/sign/out/new`, `/sign/out/edit`, `/sign/out`, and on
Auth/Core/Warp/Palm `/sign/out/complete`; Base completes on `/lobby`) and, when they are RPs, launch
logout toward Acme.

## Redirect-Only Sign Route

A retained sign-side sign-out route may:

- inspect request context needed to choose the acme logout entry;
- preserve a safe navigation target through signed redirect primitives;
- redirect the browser to acme when acting as an RP;
- render a local completion page after logout state is consumed.

It must not revoke tokens, clear acme sessions, list sessions, write logout audit as the authority,
or store logout state.

## Related

- `docs/security/session-token-authority.md`
- `docs/security/redirect-vs-ceremony-result.md`

## Delivered reconciliation (2026-10-14)

Base is the physical IdP/AS and first-party Browser RPs own only their local RP sessions and
cookies. The all-client continuation matrix verifies the completion boundary after same-realm parent
and RP-session revocation. The focused service selection covers the local parent-and-sibling-RP
transaction and rollback behavior. Local authority-first HTTP tests cover the existing Base APP/COM,
Base self-RP and Edit sequences; an independent-connection race covers concurrent sign-out and RP
refresh. The complete all-RP authority-flow and issuance-race matrix and real-browser acceptance
remain open. See
[current verification](../../evidence/2026-10-15-logout-current-doc-reconciliation-E6Q8.md). The
older Acme-only ownership statements above are retained as migration history, not as the active
boundary.
