# Authentication Capacity Admission Boundary

## Status

This document records the current implementation audit for the future authentication capacity
control described by U07 in `three.md`. It does not introduce a waiting room, a queue, a feature
flag, or a new admission state machine.

The current `AuthCeremonyAdmission` and `BaseAuthAdmissionCoordinator` contracts remain security
admissions. They are not capacity permits and must not be weakened or repurposed.

## Existing entry boundary

Base creates the OIDC or local admission for the routed surface. Auth consumes it through
`AuthCeremonyAdmission` and `AuthCeremonyContext`:

- `app/controllers/base/app/oauth/authorizations_controller.rb`
- `app/controllers/base/com/oauth/authorizations_controller.rb`
- `app/controllers/base/org/oauth/authorizations_controller.rb`
- `app/controllers/concerns/auth_ceremony_admission.rb`
- `app/services/base_auth_admission_coordinator.rb`

The admission is bound to the surface, intent, browser context, ceremony session, and parent
transaction. It is one-time and replay protected. A context-free Auth request and a mismatched or
reused admission are refused. The Auth controllers for App, Com, and Org include this boundary
before entering the surface-local Sign In, Sign Up, or verification state machine.

The following existing controls remain separate:

| Control                        | Current responsibility                                                                | Capacity meaning                                                               |
| ------------------------------ | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `AuthCeremonyAdmission`        | Redeems the Base-issued opaque admission and binds Auth ceremony continuity           | None; it proves a valid admission, not available CPU or queue capacity         |
| `BaseAuthAdmissionCoordinator` | Creates, consumes, expires, and binds Base/Auth admission and result references       | None; it protects transaction continuity and replay                            |
| `SignUpSuspensionGuard`        | Stops a surface's registration entry when the registered suspension switch is enabled | Registration availability only; it is not a Sign In or execution limiter       |
| `FqdnAvailabilityGate`         | Enforces the routed surface/FQDN availability registry                                | Served-surface availability only; it is not a capacity counter                 |
| Turnstile and rate limits      | Abuse controls at selected credential and registration requests                       | They limit abuse dimensions but do not provide a bounded expensive-work budget |

## Entry and execution map

The current routes keep Sign In and Sign Up independent. They must remain independent if a future
capacity gate is added.

| Surface and flow                  | Entry or continuation boundary                                                                         | Expensive execution that needs a future second check                                                                           |
| --------------------------------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------ |
| App Sign In                       | `auth/app/sign/ins_controller.rb`, then surface-local email, passkey, secret, or challenge controllers | Password/secret verification, email OTP issue/verify, Passkey challenge/verification, TOTP/passcode work                       |
| Com Sign In                       | `auth/com/sign/ins_controller.rb`, then email/passkey/challenge controllers                            | Email OTP issue/verify, Passkey challenge/verification, secret/passcode work                                                   |
| Org Sign In and Standby           | `auth/org/sign/ins_controller.rb` and the normal/emergency Passkey controllers                         | Operator Passkey and secret credential verification; Standby continues to forbid Step-Up                                       |
| App Sign Up                       | `auth/app/sign/ups_controller.rb`, email/telephone and social registration controllers                 | Turnstile/provider verification, OTP issue/verify, Passkey registration, secret credential hashing and finalization            |
| Com Sign Up                       | `auth/com/sign/ups_controller.rb`, email/telephone registration controllers                            | Turnstile, OTP issue/verify, Passkey registration, secret credential hashing and finalization                                  |
| Provider callback                 | App social callback controllers and registered OIDC callback paths                                     | Provider assertion validation, callback replay checks, and the subsequent Sign In/Sign Up finalizer                            |
| Resume/direct POST                | Every continuation controller retains the admission, flow/ticket, CSRF, expiry, and owner checks       | A future execution gate must be repeated immediately before the expensive operation; hiding an entry button is insufficient    |
| Completed App/Com Sign Up handoff | `finalize_sign_up_from_checkpoint!` enters canonical Sign In admission                                 | Sign In guardrails and Base session issuance remain authoritative; registration completion is not a capacity or session bypass |

This map is a boundary inventory, not a claim that every expensive operation already has an
execution-capacity limiter. The current controls prevent unauthorised or stale flow entry, but do
not impose a global concurrent Argon2id/OTP/WebAuthn budget.

## Future connection contract

When capacity admission is designed, it must receive server-derived values for surface, flow kind,
trusted admission reference, and the exact execution stage. Request parameters, `pt`, `ri`, return
URLs, actor IDs, or a FQDN string cannot be the authority for those values.

The future implementation must distinguish:

1. **Entry Control:** whether a new Sign In or Sign Up flow may be admitted.
2. **Execution Control:** whether the next expensive password, OTP, provider, or credential
   operation may begin.

An Entry decision must not grant authentication, a session, or unlimited execution. Execution checks
must be repeated on direct POST, callback, resumed flow, Passkey, social, Entra, and
Sign-Up-to-Sign-In handoff paths.

No capacity-store failure policy is accepted yet. Fail-closed, entry-only fail-open, and a bounded
local fallback have different availability and DoS consequences. Until that policy and the complete
cost map are accepted, no flag or store is enabled and existing authentication behavior remains
unchanged.

## Verification state

The current boundary audit is recorded in `five.md`, `six.md`, and the U07 ledger in `three.md`. The
existing Base/Auth and OIDC tests cover admission binding, prompt handling, replay refusal, and
surface separation. A future gate requires additional tests for normal admission, explicit denial,
direct execution requests, callback/resume paths, surface separation, and store failure according to
the accepted outage policy.
