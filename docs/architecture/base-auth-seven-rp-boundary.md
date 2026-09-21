# Base Authority and Seven RP Boundary

Canonical decision: `adr/base-auth-ceremony-and-seven-rp-boundary.md`.

Machine-readable map: `AuthBoundaryAuthorityMap`.

| Role     | Surface          | Notes                                               |
| -------- | ---------------- | --------------------------------------------------- |
| IdP / AS | Base app/com/org | `/oauth/*`, discovery, JWKS, end-session            |
| Ceremony | Auth app/com/org | Passkey/Google/Apple/Entra; app TOTP only; Jump JWKS retained |
| RP       | Core app/com/org | Rails owns neutral `GET/POST /sign` + callback      |
| RP       | Side app/com/org | Independent clients                                 |
| RP       | Edit org         | Independent `edit-org`; Publishing UI on Edit       |

Retired browser paths: `/dashboard` (Auth/Base six faces), Base `/lobby`, `/sign/out/complete`,
and the RP entry aliases `/sign/in` and `/sign/in/callback`.
