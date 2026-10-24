# Browser RP surfaces

Applies to the Palm and Tech Browser RPs and to retired surfaces. Sign-out of every Browser RP is in
[sign-out](sign-out.md). These are durable requirements, not current verification results.

## Palm

- BRP-1: `GET /sign` and HEAD start no flow; `POST /sign` requires a valid CSRF token. The callback
  accepts only a real code exchange with PKCE S256, state, nonce, issuer, audience and client
  checks; foreign, root and native credentials are refused.
- BRP-2: The native clients `app-ios-rp` and `app-android-rp` cannot authorize, exchange a code or
  refresh. No native deep link, native Bearer logout or `/api/v0/profile` response exists.
  `/api/v0/health.json`, `/api/v0/revision.json`, JWKS and the CSP report sink still answer.
- BRP-3: `/dashboard` requires the common Browser RP authentication and shows a heading, a minimal
  status and the common sign-out link, with no business function, token or internal identifier.

## Tech

- BRP-4: Tech requires a currently valid `tech.access` capability. Operator status, Entra
  authentication, Edit use and other surfaces' credentials confer no Tech access, while proper SSO
  is not forbidden.
- BRP-5: An authenticated Operator without the capability gets a 403-class response with the common
  sign-out entry, no protected content and no Tech cookie. Only state of the failed flow is cleaned;
  the parent, Edit and existing Tech sessions are untouched, and no global sign-out happens.
- BRP-6: A grant outside its validity interval, or a committed revocation, refuses the next request
  and the refresh; the user can still sign out afterwards.
- BRP-7: A failed database, key or issuer check returns no protected content and reuses no earlier
  result. Host, untrusted forwarding and return-target tampering are refused. Authenticated,
  protected and refusal responses are not cached.
- BRP-8: The dashboard is an empty tool list with a heading, empty-state text and sign-out, with
  copy under explicit translation keys. Tech is not a Jump node and has no back-channel receiver.

## Shared RP entry contract

- BRP-10: Every browser RP holds at most one pending OIDC Sign-in entry. The last `POST /sign` wins;
  an earlier tab may continue through Auth/Visa but its callback is refused at
  `GET /sign/interruption`. This behavior is per browser and RP, does not cancel another tab's
  registration, and does not replace Rails CSRF, PKCE, nonce or state verification.

## Retired surfaces

- BRP-9: The former Xper public and local hosts serve none of their former paths through Xper or
  another surface, while the same paths on retained hosts still answer.

Sources: [Tech and Palm participation](../../adr/tech-and-palm-browser-rp-participation.md),
[Xper retirement](../../adr/xper-rails-surface-retirement.md). Tech capability delegation:
[authorization](authorization.md) AUTHZ-5. Retired Device sign-in:
[authentication](authentication.md) AUTH-6.
