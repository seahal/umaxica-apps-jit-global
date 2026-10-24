# Base Authority and Seven RP Boundary

Canonical decision: `adr/base-auth-ceremony-and-seven-rp-boundary.md`.

Machine-readable map: `AuthBoundaryAuthorityMap`.

Surfaces outside this table are OAuth/OIDC Non-Participants; see
`docs/architecture/oidc-non-participant-surfaces.md`.

| Role     | Surface                      | Notes                                                                                   |
| -------- | ---------------------------- | --------------------------------------------------------------------------------------- |
| OP / AS  | Visa app/com/org             | `/oauth/*`, discovery, JWKS, authorization, token, UserInfo, revocation and end-session |
| Ceremony | Auth app/com/org             | Passkey/Google/Apple/Entra; app TOTP only; credential callbacks stay on Auth            |
| RP       | Base app/com/org             | `www.umaxica.*`; neutral `GET/POST /sign` + `GET /oidc/callback`, local RP Session      |
| RP       | Core app/com/org             | Independent clients and local RP sessions                                               |
| RP       | Warp app/com/org             | Independent clients; OIDC client IDs retain `side-*`                                    |
| RP       | Edit org, Tech org, Palm app | Independent browser RPs with host-local sessions                                        |

Retired browser paths: `/dashboard` (Auth/Base six faces), Base `/lobby`, `/sign/out/complete`, and
the RP entry aliases `/sign/in` and `/sign/in/callback`. Auth credential ceremonies may still use
`/sign/in/*`; those are not RP entrypoints and must not be used as the Core, Warp, or Edit browser
authorization boundary.

The former Rails surface name was Side. Its current internal namespace is Warp; the registered
`side-*` OIDC client identifiers, audiences, and signing namespaces remain protocol values. Visa
uses independent `VISA_APP`, `VISA_COM` and `VISA_ORG` issuer/key namespaces; Base retains
`BASE_APP`, `BASE_COM` and `BASE_ORG` for RP responsibilities. A Base RP credential is never
authority proof for Visa, and a Visa authority token is never used as a Base local RP credential.

The RP `GET /sign` entry is non-mutating. Its CSRF-protected `POST /sign` refuses a browser that is
already authenticated by either the root Browser Session or a valid access credential for that same
RP; the refusal is server-side and does not start a second OIDC transaction. A credential for
another surface is not accepted as authentication for the current RP. Sign-out remains the required
preceding ceremony.

Each browser and RP has one pending Sign-in entry. The last `POST /sign` replaces the earlier entry;
an earlier tab may continue through Auth and Visa but is refused at the RP callback and sent to
`GET /sign/interruption`. This is the intended D-155 behavior, not a defect. A Sign-up registration
that already reached its decisive commit remains saved; only its later Sign-in handoff can be
refused. Different browsers have independent pending entries.

## Protected document and image responses

Anonymous Base Dashboard documents are guided to the passive local Sign entry. Dashboard Avatar
image retrieval on app/org instead uses a bodyless 401 for non-JSON GET/HEAD; JSON keeps the
existing private-gate error. Accept, Fetch Metadata and valid Inertia headers do not turn an image
request into an interactive login. Authentication still stops the request before selected image
lookup or storage access. Authenticated image authorization, absence and storage failure contracts
remain in [the image-delivery ADR](../../adr/base-dashboard-avatar-image-delivery.md). com has no
Dashboard Avatar image route. These response differences do not change Base/Auth or Jump
responsibilities.
