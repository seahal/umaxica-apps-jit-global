# Sign-out

These are acceptance requirements for the APP, COM and ORG OP/RP surfaces. They describe expected
behavior, not evidence that a deployment has passed acceptance.

- SIGNOUT-1: A current-session OP logout requires the authenticated current browser session and
  stops exactly its Root Session and every RP grant under that root. Other roots, principals and
  realms remain unchanged. A `rp_initiated_logout` stop has scope `root` and does not advance the
  principal epoch.
- SIGNOUT-2: An authenticated RP `POST /sign/out` requires the active RP grant and its stored
  verified ID Token hint. Before redirecting to Visa, it revokes only that grant, clears its own
  access and refresh cookies, resets its local session and issues a one-use notice bound to the
  RP surface and OIDC `state`. Missing hint or callback configuration leaves the grant active.
- SIGNOUT-3: Visa accepts end-session requests by GET and POST and only stages confirmation. It
  verifies hint signature, issuer, audience, type and not-before time; it permits an expired hint.
  The supplied `client_id` must match when present. The hint subject must match the authenticated
  OP actor. Its `sid` is declined; the current OP Root Session ID is the target. A missing OP session
  or captured session ID returns `login_required` without staging, redirecting or mutating state.
- SIGNOUT-4: A return URI must exactly match the URI registered for the requesting client and
  realm. Visa adds the original OIDC `state` to the return. The RP callback consumes only a live,
  one-use notice whose surface and state match; replay, expiry, mismatch or missing notice is
  refused. Callback processing never revokes the RP grant again.
- SIGNOUT-5: Visa always shows a confirmation. Only a CSRF-protected
  `POST /oidc/logout/confirmation` can commit an RP-initiated stop. GET and HEAD at request,
  confirmation and callback boundaries do not mutate authority state; unsafe requests without a
  valid CSRF token are refused before the stop.
- SIGNOUT-6: An RP that has already cleared its local session stays signed out if the user leaves
  Visa without confirming. In that case the OP root and other RP grants remain active. On
  confirmation, the same OP stop revokes the root and all its grants; other device roots remain
  independent.
- SIGNOUT-7: A stop transaction writes one durable BCL participant for each participating grant.
  Dispatch runs after commit through Solid Queue and the recurring sweep; it never holds the OP
  authority lock or delays the browser redirect. Each receiver commits the replay receipt, absorbing
  `sid` tombstone and matching local grant revocation before answering success.
- SIGNOUT-8: A failed or rolled-back stop produces no success redirect and revokes nothing. An
  unknown commit outcome is reported as indeterminate and is not retried as a new sign-out.
  Diagnostic output never includes ID Tokens, access or refresh tokens, cookies, CSRF tokens, OIDC
  `state`, or raw session identifiers.
- SIGNOUT-9: OP authority-stop retention deletes child records before their stop and only after
  every referenced root is purge-eligible and every participant has a final delivery state.
  Restrictive foreign keys preserve the order; a rootless identity-stop record remains durable.

Sources: [logout sequence](../security/logout-sequence.md),
[logout session management](../security/logout-session-management.md),
[authority-stop contract](../../two.md#58-wu-16--wu-22--op-authority-stop-record-accepted-design-locally-implemented),
[Visa OP host decision](../../adr/visa-op-host.md).
