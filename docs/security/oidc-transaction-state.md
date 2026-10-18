# Base OIDC authorization transaction state

Base owns the OIDC authorization transaction for each surface-local ticket database. A normal
transaction has one irreversible lifecycle:

```text
pending -> authenticated -> consumed
```

Only a pending, unexpired transaction may accept an authentication result. Registration is
serialized by a row lock and rejects every other state, including an already authenticated
transaction; an accepted result cannot replace the actor, session, or authentication metadata
of an earlier result.

Only an authenticated, unexpired transaction may be consumed. Consumption is serialized by the
same transaction row lock and cannot restore or replace a terminal state. Expired transactions
cannot be authenticated or consumed.

The three concrete transaction models remain surface-local (`ClientOidcAuthorizationTransaction`,
`VisitorOidcAuthorizationTransaction`, and `OperatorOidcAuthorizationTransaction`). The model
state machine is independent of Auth-local ceremony continuity. Auth receives and returns only
purpose- and surface-bound opaque protocol state; it does not own Base transaction, Browser
Session, or RP Session authority.

For the seven first-party browser RP client IDs, an ordinary authorization request is recorded
with the neutral `authentication` intent even if a caller supplies `screen_hint=signup` or
`screen_hint=signin`. The RP therefore does not select the credential ceremony. The current
neutral handoff enters Auth through its sign-in route, where Auth retains its existing internal
Sign in / Sign up choice and special-purpose ceremonies remain separate. Native/Palm clients and
deprecated shared browser clients keep their existing purpose-specific behavior until their
explicit migration slice.

The state transition checks are exercised through the public coordinator/model API, including
authenticated-result overwrite rejection and concurrent result registration. Authorization-code
issuance, callback completion, and token/session commit ordering remain separate controls and are
verified by their later execution phases.
