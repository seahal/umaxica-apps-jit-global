# Base Authority and Seven RP Boundary

Canonical decision: `adr/base-auth-ceremony-and-seven-rp-boundary.md`.

Machine-readable map: `AuthBoundaryAuthorityMap`.

| Role     | Surface          | Notes                                               |
| -------- | ---------------- | --------------------------------------------------- |
| IdP / AS | Base app/com/org | `/oauth/*`, discovery, JWKS, end-session            |
| Ceremony | Auth app/com/org | Passkey/Google/Apple/Entra; app TOTP only; Jump JWKS retained |
| RP       | Core app/com/org | Rails owns neutral `GET/POST /sign` + `GET /sign/callback` |
| RP       | Warp app/com/org | Independent clients; OIDC client IDs retain `side-*` |
| RP       | Edit org         | Independent `edit-org`; Publishing UI on Edit       |

Retired browser paths: `/dashboard` (Auth/Base six faces), Base `/lobby`, `/sign/out/complete`,
and the RP entry aliases `/sign/in` and `/sign/in/callback`. Auth credential ceremonies may still
use `/sign/in/*`; those are not RP entrypoints and must not be used as the Core, Warp, or Edit
browser authorization boundary.

The former Rails surface name was Side. Its current internal namespace is Warp; the registered
`side-*` OIDC client identifiers, audiences, and signing namespaces remain protocol values.

The RP `GET /sign` entry is non-mutating. Its CSRF-protected `POST /sign` refuses a browser that is
already authenticated by either the root Browser Session or a valid access credential for that
same RP; the refusal is server-side and does not start a second OIDC transaction. A credential for
another surface is not accepted as authentication for the current RP. Sign-out remains the
required preceding ceremony.


## Protected document and image responses

Anonymous Base Dashboard documents are guided to the passive local Sign entry.
Dashboard Avatar image retrieval on app/org instead uses a bodyless 401 for
non-JSON GET/HEAD; JSON keeps the existing private-gate error. Accept, Fetch
Metadata and valid Inertia headers do not turn an image request into an interactive
login. Authentication still stops the request before selected image lookup or
storage access. Authenticated image authorization, absence and storage failure
contracts remain in [the image-delivery ADR](../../adr/base-dashboard-avatar-image-delivery.md).
com has no Dashboard Avatar image route. These response differences do not change
Base/Auth or Jump responsibilities.
