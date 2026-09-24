# Step-Up Ceremony Delegation

> **Legacy Sign/Acme vocabulary:** The `sign/id` → `acme/www` signed-result flow below is historical
> context. It must not be used to design a new handoff. Current Rails Base/Auth OIDC finalization
> follows the opaque, generation-bound result contract documented in
> `docs/security/ceremony-grant-result.md`; the session-bound freshness decision remains owned by
> the current session authority.

## Boundary

Step-up has two separate parts:

- `sign/id` executes the credential ceremony.
- `acme/www` owns the session-bound freshness decision and storage.

`sign/id` must not store `recent_auth`, `sudo`, `last_step_up_at`, AAL freshness, or equivalent
session freshness. A successful sign ceremony is evidence only until acme consumes the signed
ceremony result.

Step-up is not sign-in and does not create a new `ClientToken`, `ClientDeviceSession`, or login
unit. It updates freshness on the existing session only after acme accepts the ceremony result. If
the session is revoked, the ceremony grant is replayed, or the identity does not match the current
session, the result consumer must fail closed.

## Flow

1. `acme/www` decides that a sensitive action requires step-up.
2. `acme/www` issues a ceremony grant for the required purpose and session.
3. `sign/id` executes the allowed credential ceremony.
4. `sign/id` returns a signed ceremony result.
5. `acme/www` validates and consumes the result.
6. `acme/www` commits or rejects step-up freshness for the session.

The `sign/id` completion boundary is one-time as well: the surface-local pending step-up row is
locked in PostgreSQL, the result is issued inside that transaction, and the row is destroyed before
commit. A concurrent request cannot issue a second result from the same ticket.

## Non-Goals

- Do not treat credential registration as step-up freshness: a credential that is just being
  registered does not silently satisfy a later sensitive action. The credential-management
  mutation itself is still behind the existing Step-Up boundary on every Base surface. The first
  credential may use the documented bootstrap path; subsequent create, update, and destroy
  requests require fresh, session-bound `settings_secret_credential` Step-Up. The direct secret
  credential routes and the dedicated removal routes share this requirement.
- Do not let policy code perform ceremony side effects.
- Do not use redirects or return targets as proof that step-up succeeded.

## Related

- `docs/security/authentication-assurance-levels.md`
- `docs/security/ceremony-grant-result.md`
