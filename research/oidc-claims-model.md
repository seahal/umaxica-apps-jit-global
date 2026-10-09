# OIDC Claims Model Note

This note records the current preferred direction for OIDC token claims used by relying-party
surfaces.

## Purpose

The goal is to keep claim semantics simple, stable, and aligned with the repository's existing
`Verification` / `StepUp` model.

This note focuses on:

- `acr`
- `amr`
- related session and verification semantics

## `id_token` claim contract

### Must include

- `iss`
- `sub`
- `subject_type`
- `aud`
- `exp`
- `iat`
- `auth_time`
- `sid`
- `nonce`
- `acr`
- `amr`

### Should include

- `jti`

### Must not include

- raw email address
- telephone number
- internal numeric primary key
- internal foreign key values
- profile attributes
- preference payload
- business authorization details
- passcode internals

### Notes

- `sub` is the stable subject identifier
- `subject_type` is the explicit subject category used to avoid overloading `sub`
- `act` is intentionally not used

## General Direction

- use OIDC-style claims
- keep claim values small and explicit
- avoid exception-heavy claim semantics
- treat `acr` as the current verification level, not as a permanent statement about the user's
  strongest available factor
- treat `amr` as the set of methods actually used to establish the current authentication state

## `acr`

The product AAL boundaries and per-surface method lookup are defined in
`adr/authentication-assurance-level-boundaries.md` and
`docs/security/authentication-assurance-levels.md`.

For current OIDC token paths, normal sign-in emits `aal1`, explicit verification / step-up may emit
`aal2`, and refresh downgrades back to `aal1`. `aal3` is reserved and not currently emitted.

### Important design choice

`aal2` is temporary.

It is not meant to permanently describe the user's strongest credential. It describes the current
verification state for the active access context.

## `amr`

### Allowed values

- `email_otp`
- `passkey`
- `apple`
- `google`
- `passcode`
- `totp`

### Meaning

`amr` contains the methods actually used to establish the current authentication state.

It must **not** be used as:

- the full list of methods available to the user
- the set of all registered authenticators
- a profile of everything the user could use in the future

### Examples

#### Email login only

```json
["email_otp"]
```

#### Google login only

```json
["google"]
```

#### Passkey login only

```json
["passkey"]
```

#### Passcode login only

```json
["passcode"]
```

#### Email login followed by TOTP verification

```json
["email_otp", "totp"]
```

#### Google login followed by passkey verification

```json
["google", "passkey"]
```

### Ordering

Preferred ordering is:

1. primary sign-in method
2. later verification / step-up method(s)

This keeps the sequence readable even though `amr` is primarily treated as the set of methods
actually used.

## Related Claims

### `sid`

`sid` should be included so the issued token can be tied to a concrete session lineage.

This supports:

- session management
- session revoke
- global sign-out follow-up handling
- future hard-revoke design

### `auth_time`

`auth_time` should be included to describe when the user last authenticated.

This is useful for:

- step-up authentication decisions
- step-up decisions
- security-sensitive UX

### `nonce`

`nonce` should be used for OIDC callback safety and validated by the relying party.

## Verification Interaction

The claim model is intentionally aligned with the repository's existing verification model:

- normal sign-in produces `aal1`
- explicit verification upgrades to `aal2`
- `Verification Expired` should force a new step-up path
- `Verified Access` should use current verification/session state rather than relying only on token
  claims

## Refresh Interaction

Refresh is intentionally conservative:

- refreshed access tokens return to `acr=aal1`
- step-up-derived elevation is not preserved across refresh

This keeps elevated assurance intentionally short-lived.

## Status

This note defines the preferred claim model. It does not imply that every current token path in the
repository already implements all of these rules.
