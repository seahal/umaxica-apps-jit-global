# Sign-out

Applies to first-party sign-out over the shared Ticket databases: the IdP (Base) and every
registered first-party Browser RP — Base Self-RP, Core, Warp, Edit, Palm and Tech, in the app, com
and org realms where each exists. These are durable requirements, not current verification results.

- SIGNOUT-1: A global sign-out revokes the parent Device Session, its root lineage, the origin RP row
  and every sibling RP row in one transaction. Other parents of the same actor and other actors stay
  unchanged, an already-revoked historical row keeps its revocation, and no HTTP request is sent to
  an RP. An RP credential or a challenge alone revokes no parent.
- SIGNOUT-2: Every caller that ends a parent — IdP sign-out, sign-out of all sessions, revocation of
  a selected session, account-level emergency, risk and credential-transition revocation — revokes
  the parent and all of its RP rows together, enqueues no delivery job, and never falls back to
  revoking a token alone.
- SIGNOUT-3: Only the current IdP session that owns the parent can confirm its revocation. A
  different parent, actor, device, root family, a regressed root generation or a substituted
  session identifier revokes nothing; a legitimately rotated root of the same family is accepted.
  Authority is checked again after the parent is locked.
- SIGNOUT-4: GET and HEAD on initiation, confirmation and completion change no row. An unsafe
  confirmation without a valid CSRF token or from another site is refused before any effect. An
  `id_token_hint` identifies a session and never authorizes; an unregistered or inexact
  `post_logout_redirect_uri` is refused before redirect.
- SIGNOUT-5: A failure inside the transaction revokes nothing and produces no success output. A
  failure after the COMMIT — origin cookie cleanup or the progress write — shows the global result
  with cleanup incomplete, never a sign-out failure, and recreates nothing. When the parent state
  cannot be read, the result is indeterminate (no-store 503) and nothing is retried.
- SIGNOUT-6: After a committed parent revocation, an unexpired credential of that parent is refused
  at its next browser request and safe refresh, and the RP clears its cookies. A revocation is
  read from the Ticket writer and is not hidden by a query cache; an unreadable Ticket database
  fails closed with no protected content.
- SIGNOUT-7: The completion display derives from the parent state, states the global result and
  never states an end time. Sign-out failure logs carry no actor, token or session identifier.
- SIGNOUT-8: When the IdP session is absent or belongs to another account, the IdP revokes nothing,
  changes no session or intent row, answers with a localized no-store error and does not redirect to
  the completion URI; the origin RP session keeps working. No path ends only the origin RP session.
- SIGNOUT-9: The sign-out intent expires 10 minutes after creation and is refused at and after
  expiry; a COMMIT made before expiry stays committed. Starting again from the same RP session
  reuses its unfinished intent; an intent of another RP session or browser is never reused. The
  proof is filtered from logs and never appears in a redirect URL. Completion uses the exact
  registered `/sign/out/completion` URI bound to client, realm and state.
- SIGNOUT-10: First-party back-channel logout does not exist: no receiver route, no back-channel
  declaration in discovery, no BCL URI on a registered client and no delivery job. ID Tokens still
  carry `sid`.

Sources: [shared-database sign-out](../../adr/first-party-sign-out-shared-database-without-backchannel-logout.md),
[logout primitive](../../adr/logout-primitive-and-composition.md),
[logout completion](../../adr/logout-completion-boundary.md),
[logout target authorization](../../adr/sign-neutral-entry-and-logout-target-authorization.md),
[logout session management](../security/logout-session-management.md).
Session issuance and revocation failures: [session management](session-management.md).
