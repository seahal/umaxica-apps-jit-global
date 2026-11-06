# Logout Sequence

Visa is the OpenID Provider (OP); Base, Core, Warp, Edit, Palm and Tech are relying-party (RP)
surfaces. Each surface owns its host-only cookies, local session and completion route. APP, COM and
ORG are separate realms.

## RP initiation

An authenticated RP accepts `POST /sign/out` with CSRF protection. A separated RP cell resolves the
local session from its verified access credential, captures only the Refresh cookie whose `sid`
matches that session and its access JWT, and commits local session revocation first. A local commit
failure returns 503 before reporting sign-out. The RP then clears its own cookies, resets its local
session, stores a one-use notice bound to its surface and a random `state`, and sends the captured
Refresh Token to the registered Visa `/revoke` endpoint using the client's registered authentication
method. The request is bounded to two seconds and one network retry. Revocation failure does not
restore the local session; that grant remains bounded by its original expiry. No token enters a URL,
log or job payload.

The RP redirects to Visa with the registered `client_id`, exact registered
`post_logout_redirect_uri` and `state`; it does not need to persist or send an ID Token hint. This
starts the independent OP-wide confirmation. If the browser has no usable Visa session, Visa changes
no authority and returns through Jump to that registered RP completion. With an active Visa session,
the user can confirm stopping the OP device or leave it active. Either outcome leaves the initiating
RP locally signed out. Other RP sessions are not copied or stopped by the local logout.

The RP logout controllers in this checkout use the local-session-first launcher and do not read or
send a stored ID Token hint. A separate shared-role branch in `BrowserRpAuthentication` still reads
the OP grant chain for ordinary request authentication and refresh. That WU-A8 gap does not change
the launcher behavior described above, and it leaves the end-to-end shared-role authentication
surface unreconciled.

## OP request and confirmation

Visa accepts GET and POST end-session requests without changing authority. It verifies the hint's
signature, issuer, audience, type and not-before time; expiration alone does not reject a hint. The
client and return URI must match the realm's registration. The hint `sid` identifies an RP grant;
Visa resolves that grant and requires its root to belong to the browser's current Visa device
session. A verified hint without that session or with a foreign grant is refused with 403. Invalid
requests show a localized generic message in HTML; JSON retains the protocol error details. Without
a hint Visa may still validate a supplied `client_id` and exact registered return URI. If the
browser has no usable OP session, Visa stages nothing and returns through Jump to that URI with the
original `state`; without a usable return it renders an already-signed-out page. With a usable OP
session, Visa stages the current device for its independent confirmation. An ID Token hint is not
required to select or revoke the initiating RP session.

A valid request stores the device and resolved grant in the Visa browser session and presents a
confirmation. The CSRF-protected confirmation POST rechecks the device. A changed device is refused;
an already-revoked device is reported as already signed out. A valid confirmation stops every root
row of that device's rotation lineage, writes one root stop per row, stops their grants and revokes
the device. Other device sessions remain active.

A rolled-back stop retains Visa cookies and the pending request and returns an error. An unknown
commit returns 503 while preserving them; retry rechecks the same device. Once the stop is known
committed, Visa clears its cookies and session. It redirects through Jump to the validated
registered RP return with the original state, including a no-hint request, or to its own one-use
completion page when there is no usable return. If notice storage or redirect construction fails
after commit, Visa renders its signed-out page directly. The browser response does not wait for
Back-Channel Logout delivery.

## Completion and Back-Channel Logout

The RP completion accepts a live, one-use notice whose surface and state match and refuses an active
session, a replay or a mismatch. Visa's own completion also consumes a one-use notice and refuses a
reload. Both pages leave authority unchanged. A stale confirmation without a pending request is
refused; a repeat of a completed confirmation without a current session reports already signed out.

The OP stop transaction writes one durable Back-Channel Logout participant per stopped grant. Solid
Queue and the recurring sweep deliver after commit. Each RP receiver commits its replay receipt,
`sid` tombstone and matching local-session revocation before it answers success. Delivery does not
decide whether the OP stop committed. HTTP 200 and 204 acknowledge delivery; other responses follow
the retry or refusal policy. Discovery advertises session-aware back-channel logout, and the ID
Token and Logout Token use the grant public ID as `sid`.

## Boundaries and evidence

Visa refuses `logout_challenge`; Auth sign-out clears its own ceremony state and hands off to Base.
The RP, Visa and each receiver retain separate ownership of cookies, sessions, routes and state. See
[session management](logout-session-management.md),
[the OP host decision](../../adr/visa-op-host.md), and
[the separated-store logout decision](../../adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md).
Local checks do not establish production deployment or external RP delivery.
