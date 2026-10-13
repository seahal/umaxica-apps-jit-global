# Tech Joins and Palm Changes Role in the OAuth/OIDC Participation Allowlist

## Status

Accepted (2026-10-13). User decision.

This is a **target contract**. At commit `9c6a0fcaee7d88e94892e2b24f2b2dbe70c89c1e` Tech does not
exist and Palm is still a native relying party.

Required by `adr/oidc-oauth-participation-allowlist-and-non-participant-surfaces.md`, whose
Reclassification Rule says that moving a surface into the OAuth/OIDC system needs a new accepted ADR
and explicit admission to the participation allowlist, and lists what that ADR must define. Each
heading below answers one item of that list.

## Context

Two changes to who participates in OAuth/OIDC are planned:

- **Tech** is a new operator surface on `tech.umaxica.org`. It does not exist yet, so under the
  allowlist ADR it is a Non-Participant by default.
- **Palm** is today an approved _native_ RP: public clients `app-ios-rp` and `app-android-rp`, an
  app-scheme completion, and a bearer-token API. It is to become an ordinary first-party _browser_
  RP, and the native role is to be retired with no backward compatibility.

Neither change may be inferred from sharing a database, a TLD or code with an existing participant.

## Decision

Tech is admitted as an approved first-party RP client and RP face. Palm's role changes from approved
native RP client to approved first-party RP client and RP face, and its native role ends. Both use
the common Browser RP components already used by Core, Warp and Edit, and neither inherits any
authority, credential or session from another surface.

### Protocol role

|                       | Tech                                                   | Palm                                        |
| --------------------- | ------------------------------------------------------ | ------------------------------------------- |
| Role                  | First-party browser RP, confidential client            | First-party browser RP, confidential client |
| Actor and realm       | Operator, org                                          | Client, app                                 |
| Flow                  | Authorization code with PKCE S256, `state` and `nonce` | Same                                        |
| Client authentication | `private_key_jwt`                                      | `private_key_jwt`                           |

Base stays the only IdP and Authorization Server. Neither surface issues tokens.

### Client identity

|                      | Tech       | Palm                                                                                    |
| -------------------- | ---------- | --------------------------------------------------------------------------------------- |
| Client ID            | `tech-org` | `palm-app`                                                                              |
| Client key namespace | `TECH_ORG` | `PALM_APP` (as an OIDC client namespace, in addition to its existing surface namespace) |
| Retired identities   | none       | `app-ios-rp`, `app-android-rp`; never reused with another meaning                       |

Both client IDs are added to `AuthBoundaryAuthorityMap` as approved RP clients; that addition is the
admission to the allowlist.

### Issuer and audience bindings

The issuer is the existing Base issuer of the surface's realm (org for Tech, app for Palm). The
audience is the client's own ID (`tech-org`, `palm-app`). A token whose issuer, audience or client
belongs to another surface or realm is refused. Palm's native audience `palm-api` is retired with
the native API.

### Redirect URI and logout endpoints

|                     | Tech                                                                        | Palm                                          |
| ------------------- | --------------------------------------------------------------------------- | --------------------------------------------- |
| Entry               | `GET /sign` (displays, issues no flow), `POST /sign` (CSRF-protected start) | Same                                          |
| Redirect URI        | `https://tech.umaxica.org/oidc/callback`, exact match                       | The Palm host's `/oidc/callback`, exact match |
| Sign-out start      | `/sign/out`                                                                 | `/sign/out`                                   |
| Sign-out completion | `/sign/out/completion`, exact registered URI                                | Same                                          |
| Back-Channel Logout | none                                                                        | none                                          |

Local development uses the corresponding `*.localhost` hosts. Palm's app-scheme completion URIs are
removed. No parallel browser or native entry path exists beside these.

### RP Session ownership

Tech RP sessions are `OperatorRpSession` rows on the org Ticket database, under the operator's
parent Browser Session, exactly where Edit's are. Palm RP sessions are `ClientRpSession` rows on the
app Ticket database. Sharing the storage does not share a session: each row is bound to its own
client ID, and one active row exists per parent and client.

### Access and Refresh Token transport, and cookie boundaries

Both surfaces carry the RP access and refresh credentials in host-only browser cookies under the
common Browser RP credential contract. A cookie of Edit, Core, Warp, the Base Self-RP or the IdP is
never accepted by Tech or Palm, and theirs are never accepted elsewhere. Palm no longer accepts
Bearer tokens for user authentication; there is no bridge from a native or Bearer credential to a
cookie.

### Refresh behavior

The common safe-request and unsafe-request refresh orchestrators apply unchanged: an unsafe request
passes CSRF and origin checks before refresh; refresh is refused when the parent is revoked or
unusable; RP refresh expiry never exceeds the parent's absolute expiry. Tech additionally refuses
refresh when `tech.access` is no longer held.

### UserInfo behavior

No surface-specific behavior. Tech and Palm use the IdP's UserInfo endpoint and the common identity
provisioning exactly as the existing browser RPs do.

### Sign-out semantics

Both follow `adr/first-party-sign-out-shared-database-without-backchannel-logout.md`: sign-out is
IdP-first, the IdP revokes the parent and all of its RP session rows in one transaction, and a
revoked parent is refused at the next request and refresh. When the IdP has no matching session,
nothing is revoked and the flow stops with an error. Tech's business permission never blocks
sign-out.

### Authorization beyond authentication (Tech only)

Being authenticated is not being authorized. Tech requires the operator capability `tech.access`,
checked before a usable Tech credential is saved, on every protected request and on refresh.
Operator status, Entra sign-in or access to Edit confers nothing. `tech.access` is delegable under
the existing capability rules: the granter holds `iam.capability.read`, `iam.capability.grant` and
their own valid `tech.access`, cannot grant to themselves, and validity is finite and at most 366
days.

### Removal of previous assumptions

- Palm: the native RP role, the public clients, the app-scheme completion, the bearer profile API
  (`/api/v0/profile`), the native access-token authenticator and the native logout coordinator are
  removed. Records of old sessions and tokens are kept and made ineffective; they are not deleted.
  Machine endpoints (`/api/v0/health.json`, `/api/v0/revision.json`), JWKS and the CSP report sink
  remain.
- Tech: nothing to remove; it must not be treated as part of Edit because it shares Edit's databases
  and `.org` domain.
- Neither surface is added to the Jump graph by this decision. Palm keeps its existing Jump edges;
  Tech has none.

### Regression tests proving surface isolation

- A credential of Edit, Core, Warp, the Base Self-RP, the IdP or the retired Palm clients is refused
  by Tech and by Palm, and the reverse.
- A token with another surface's audience, client or realm is refused.
- The retired Palm client IDs cannot authorize, exchange a code or refresh.
- `GET /sign` issues no flow on either surface; `POST /sign` without a valid CSRF token is refused.
- Tech without `tech.access` reaches no protected content and receives no Tech authentication
  cookie; loss of the capability stops requests and refresh while sign-out still works.
- A global sign-out started at either surface revokes the parent and every RP row under it, and a
  sign-out started elsewhere ends acceptance at Tech and Palm at their next request.

## Consequences

- The allowlist grows by two client IDs and loses the native role. The static client store and the
  key namespace list change accordingly.
- Existing native Palm apps, if any are in use, stop authenticating. Whether any are in use has not
  been established; that question is a condition for release, not for this decision.
- Tech needs a host, environment variables, a capability catalog entry and a database constraint
  change before any Tech code can run.
- Admission to the allowlist takes effect in code when the two client IDs are added to
  `AuthBoundaryAuthorityMap`; until then the surfaces remain Non-Participants in practice.

## Alternatives considered

- **Treat Tech as part of Edit.** Rejected: it would let Edit's client, session and permissions
  carry authority on a surface with a different purpose.
- **Keep Palm native and add a browser path beside it.** Rejected: two credential models on one
  surface, and a path from one to the other, are the kind of mixed dispatch the Base and Self-RP
  separation exists to prevent.
- **Skip this ADR because the planning record already approves the work.** Rejected: the allowlist
  ADR makes a new accepted ADR the admission mechanism, and the planning files are not tracked.
