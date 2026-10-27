# Sign-out

These are acceptance requirements for the APP, COM and ORG OP/RP surfaces. They describe expected
behavior, not evidence that a deployment has passed acceptance.

- SIGNOUT-1: A current-session OP logout stops the current Visa device session, every root row in
  its rotation lineage and every grant under that device. Each root has its own
  `rp_initiated_logout` stop of scope `root`; the principal epoch does not advance. Other devices,
  principals and realms stay independent.
- SIGNOUT-2: An authenticated RP `POST /sign/out` reads its grant's stored verified ID Token and
  registered return URI, clears its host-only credentials, resets its session and stores a one-use
  notice bound to its surface and OIDC `state`. It makes no OP authority write or endpoint call.
  A separated RP cell can revoke its own local session. Missing hint or callback configuration
  refuses the launch without ending the grant.
- SIGNOUT-3: Visa validates hint signature, issuer, audience, type and not-before time and accepts
  an expired hint. The supplied `client_id` must match. A verified hint's `sid` must identify a
  grant for that client whose root belongs to the current Visa device session. A missing OP session
  or a grant outside that device is refused with 403. Invalid requests show localized generic HTML
  text; JSON retains its protocol error. A request without a hint or OP session renders
  the distinct already-signed-out page without staging or redirecting.
- SIGNOUT-4: A return URI must exactly match the URI registered for the requesting client and
  realm. Visa adds the original OIDC `state` to the return. The RP completion consumes only a live,
  one-use notice whose surface and state match; replay, expiry, mismatch, an active session or a
  missing notice is refused. Without a usable return URI, Visa's own completion page consumes its
  one-use notice and refuses a reload. Completion pages do not mutate authority.
- SIGNOUT-5: Only a CSRF-protected `POST /oidc/logout/confirmation` can commit an RP-initiated stop.
  End-session GET and POST requests stage a device-bound confirmation or refuse the request; they
  do not change authority. Unsafe requests without a valid CSRF token are refused before the stop.
- SIGNOUT-6: If the user leaves Visa without confirming, the initiating RP remains signed out
  locally, while its OP grant, the OP device session and other RP grants remain active. Confirmation
  stops the device and its lineage; other devices remain independent.
- SIGNOUT-7: A stop transaction writes one durable BCL participant for each participating grant.
  Dispatch runs after commit through Solid Queue and the recurring sweep; it never holds the OP
  authority lock or delays the browser redirect. Each receiver commits the replay receipt, absorbing
  `sid` tombstone and matching local grant revocation before answering success.
  HTTP 200 and 204 acknowledge delivery; other responses follow the retry or refusal policy.
  Discovery advertises session-aware back-channel logout, and the ID Token and Logout Token use the
  grant public ID as `sid`.
- SIGNOUT-8: A rolled-back stop returns an error, retains Visa cookies and the pending request, and
  never redirects as success. An unknown commit returns 503 with the same state retained; a retry
  rechecks the same device. Once a stop is known committed, later presentation or redirect failure
  renders the signed-out page. A stale confirmation is refused with 422, a changed current device
  with 403, and a repeat of an already stopped device shows already signed out. Diagnostic output
  never includes ID Tokens, access or refresh tokens, cookies, CSRF tokens, OIDC `state`, or raw
  session identifiers.
- SIGNOUT-9: OP authority-stop retention deletes child records before their stop and only after
  every referenced root is purge-eligible and every participant has a final delivery state.
  Restrictive foreign keys preserve the order; a rootless identity-stop record remains durable.

Sources: [logout sequence](../security/logout-sequence.md),
[logout session management](../security/logout-session-management.md),
[the separated-store logout decision](../../adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md),
[Visa OP host decision](../../adr/visa-op-host.md).
