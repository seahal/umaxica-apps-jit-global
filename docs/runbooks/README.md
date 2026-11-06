# Runbooks

A runbook is the current, executable procedure an operator follows against a deployed environment, a
shared database or an external provider console when a defined trigger occurs: a key rotation, a
rollout, a provisioning step, or an incident. Every runbook lives in this directory.

## Boundaries

- `adr/` holds why a decision was made. A runbook links to the ADR and does not restate it.
- `docs/operations/` holds standing operational contracts, inventories and development-environment
  procedures. A document there describes how something is configured or must stay configured; when
  it would tell an operator to change a deployed environment or provider, that procedure belongs
  here.
- `docs/security/` holds security contracts. A runbook links to the contract it executes.
- `evidence/` holds what was actually done. A runbook states intended steps; a completed run that is
  worth retaining leaves an evidence record, and the runbook is never edited to claim a run
  happened.
- `specs/` holds accepted changes in progress. A procedure that outlives the change is promoted
  here.

## Contents of a runbook

Use the sections that carry content and omit the rest:

1. Scope and trigger: what the procedure covers, what it does not, and when to run it.
2. Prerequisites and owners: required access, approvals, configuration and the governing ADR or
   contract.
3. Procedure: ordered steps an operator can follow without reading the code.
4. Verification: observable checks that confirm each step or the final state.
5. Rollback or recovery: how to stop and return to a known state, or a statement that a step is
   irreversible and the approval it requires.
6. Current status: rollout or implementation progress, when the runbook carries any.

Runbooks never contain secret values, private keys, client secrets, tokens, tenant identifiers or
complete provider subjects. Refer to the approved secret inventory instead.

## Naming and maintenance

- File names are lowercase and hyphenated, describe the subject, and carry no `-runbook` suffix.
- The directory is flat.
- Update a runbook in the same change as the implementation, configuration or decision that changes
  its procedure. Code comments, ADRs and current docs link to the runbook by its path here.
- Retire a runbook by deleting it once its procedure no longer applies, and update every current
  reference in the same change. Historical citations in `evidence/`, `research/` and
  `plans/archive/` keep their original paths.

## Index

| Runbook                                                                             | Covers                                                                                     |
| ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| [Apple second key](apple-second-key.md)                                             | Second Sign in with Apple key creation in the Apple developer portal                       |
| [ChainSeal key rotation](chain-seal-key-rotation.md)                                | ChainSeal ES384 key rotation and emergency revocation                                      |
| [Device session token integrity rollout](device-session-token-integrity-rollout.md) | Precondition checks and migration order for device session and token reference constraints |
| [Entra ID Org login](entra-org-login.md)                                            | Microsoft Entra application registration and enablement for the Org login ceremony         |
| [Jump RT key rotation](jump-rt-key-rotation.md)                                     | ES384 signing key rotation for Jump redirect tokens                                        |
| [JWT key rotation](jwt-key-rotation.md)                                             | Access token, Preference token, OIDC ID Token and JWKS key rotation                        |
| [Operator capability](operator-capability.md)                                       | Bootstrap, grant, revocation and audit procedures for org administrative capabilities      |
| [Passkey](passkey.md)                                                               | AAGUID catalog maintenance and passkey operations                                          |
| [Stuck sign-up registration](stuck-sign-up-registration.md)                         | Reading and acting on stuck APP registration reports                                       |
| [Tech browser RP](tech-browser-rp.md)                                               | Tech Operator RP rollout and recovery                                                      |
| [Unified enforcement rollout](unified-enforcement-rollout.md)                       | Deployment, provisioning order and verification for unified enforcement                    |
