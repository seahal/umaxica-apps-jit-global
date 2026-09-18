# Base Authority and Seven RP Boundary

Canonical decision: `adr/base-auth-ceremony-and-seven-rp-boundary.md`.

Machine-readable map: `AuthBoundaryAuthorityMap`.

| Role     | Surface          | Notes                                               |
| -------- | ---------------- | --------------------------------------------------- |
| IdP / AS | Base app/com/org | `/oauth/*`, discovery, JWKS, end-session            |
| Ceremony | Auth app/com/org | Passkey/TOTP/Google/Apple/Entra; Jump JWKS retained |
| RP       | Core app/com/org | Rails owns `/sign/in` + callback                    |
| RP       | Side app/com/org | Independent clients                                 |
| RP       | Edit org         | Independent `edit-org`; Publishing UI on Edit       |

Retired browser paths: `/dashboard` (Auth/Base six faces), Base `/lobby`, `/sign/out/complete`.
