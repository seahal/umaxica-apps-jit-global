# Logout Sequence

Visa is the OpenID Provider (OP); Base, Core, Warp, Edit, Palm and Tech are relying-party (RP)
surfaces. Each surface owns its host-only cookies, local session and completion route. APP, COM and
ORG are separate realms.

## RP initiation

An authenticated RP accepts `POST /sign/out` with CSRF protection. It reads the verified ID Token
stored for its grant and selects the exact registered `post_logout_redirect_uri` for its host and
region. A missing hint or callback refuses the launch. The RP clears its own access and refresh
cookies, resets its local session, stores a one-use notice bound to its surface and a random
`state`, and redirects the browser to Visa with the hint, client ID, return URI and state. The shared
RP path makes no OP authority write or endpoint call; a separated cell can end its own local session.

Leaving Visa without confirming leaves the initiating RP signed out locally. The OP device session,
the initiating grant and the other RP grants remain active.

## OP request and confirmation

Visa accepts GET and POST end-session requests without changing authority. It verifies the hint's
signature, issuer, audience, type and not-before time; expiration alone does not reject a hint.
The client and return URI must match the realm's registration. The hint `sid` identifies an RP
grant; Visa resolves that grant and requires its root to belong to the browser's current Visa
device session. A verified hint without that session or with a foreign grant is refused with 403.
Invalid requests show a localized generic message in HTML; JSON retains the protocol error details.
Without a hint or OP session Visa renders an already-signed-out page and stages nothing.

A valid request stores the device and resolved grant in the Visa browser session and presents a
confirmation. The CSRF-protected confirmation POST rechecks the device. A changed device is refused;
an already-revoked device is reported as already signed out. A valid confirmation stops every root
row of that device's rotation lineage, writes one root stop per row, stops their grants and revokes
the device. Other device sessions remain active.

A rolled-back stop retains Visa cookies and the pending request and returns an error. An unknown
commit returns 503 while preserving them; retry rechecks the same device. Once the stop is known
committed, Visa clears its cookies and session. It redirects through Jump to the registered RP return
with the original state, or to its own one-use completion page when there is no usable return. If
notice storage or redirect construction fails after commit, Visa renders its signed-out page directly.
The browser response does not wait for Back-Channel Logout delivery.

## Completion and Back-Channel Logout

The RP completion accepts a live, one-use notice whose surface and state match and refuses an active
session, a replay or a mismatch. Visa's own completion also consumes a one-use notice and refuses a
reload. Both pages leave authority unchanged. A stale confirmation without a pending request is
refused; a repeat of a completed confirmation without a current session reports already signed out.

The OP stop transaction writes one durable Back-Channel Logout participant per stopped grant. Solid
Queue and the recurring sweep deliver after commit. Each RP receiver commits its replay receipt,
`sid` tombstone and matching local-session revocation before it answers success. Delivery does not
decide whether the OP stop committed.
HTTP 200 and 204 acknowledge delivery; other responses follow the retry or refusal policy.
Discovery advertises session-aware back-channel logout, and the ID Token and Logout Token use the
grant public ID as `sid`.

## Boundaries and evidence

Visa refuses `logout_challenge`; Auth sign-out clears its own ceremony state and hands off to Base.
The RP, Visa and each receiver retain separate ownership of cookies, sessions, routes and state. See
[session management](logout-session-management.md), [the OP host decision](../../adr/visa-op-host.md),
and [the separated-store logout decision](../../adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md).
Local checks do not establish production deployment or external RP delivery.
