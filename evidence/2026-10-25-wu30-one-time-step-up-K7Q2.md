# WU-30: one-time, operation-bound Step-Up consumption (ADR authentication-security-mode D3)

Commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`, with about 270 uncommitted files from this
cycle and from concurrent sessions in the worktree (OIDC refresh/logout, Design D admission). Those
changes affect the wider runs below; the narrow run is unaffected by them.

## Production changes

- `TokenStatusManagement#consume_step_up_evidence!(requirement:, now: nil)` (APP/COM/ORG tokens):
  under the token row lock it refuses unless the requirement names the token's owner and
  `StepUpResolver` accepts the evidence (operation = scope/purpose/audience, target = `resource_ref`
  and `tenant_ref`, session and token binding, Security Mode window), then clears the evidence.
  It raises `StepUpEvidenceUnavailable`; a requirement without Step-Up raises `ArgumentError`.
  Callers invoke it inside the transaction that commits the operation, so a rollback restores it.
- `CLEARED_STEP_UP_EVIDENCE` is shared with `revoke_step_up_authority!` (no behavior change there).
- Consumption wired after the successful write in:
  - `IdentityPasskeyNameCommitter` (APP/COM/ORG; an unchanged name consumes nothing);
  - `IdentityPasskeyRegistrationFinalCommitter` (non-bootstrap; APP/COM/ORG);
  - `ClientSecretNameCommitter`, `ClientSecretRevocationCommitter` (APP; an idempotent replay of a
    completed revocation now needs a new Step-Up);
  - `EmailCredentialRegistrationOtpFinalizer` (non-bootstrap), `TelephoneCredentialRegistrationOtpFinalizer`
    (APP/COM), `OperatorEmailRegistrationOtpFinalizer`, `OperatorTelephoneRegistrationOtpFinalizer` (ORG).
- Already one-time before this change, through `CredentialSecurityTransition` (revokes Step-Up on
  every token of the actor): credential removal (`IdentityCredentialRemovalCommitter`) and the APP/COM
  Security Mode switch. The 2026-10-24 "Not done" item on the downgrade Step-Up is therefore met.

## Tests

- New `test/models/concerns/token_step_up_evidence_consumption_test.rb` (11 runs): reuse refused
  on APP/COM/ORG; wrong scope, audience, target (other and absent), actor and session refused with
  the evidence kept; NORMAL 15 min − 1 s / 15 min / 15 min + 1 s and ADVANCED 5 min − 1 s / 5 min /
  5 min + 1 s; rollback keeps the evidence; a non-Step-Up requirement is refused.
- New cases: second passkey rename refused on every surface; second Secret rename refused;
  registration finalization spends the settings Step-Up; HTTP rename then delete with the same
  Step-Up returns 401 on APP/COM/ORG and succeeds after a new Step-Up.
- Changed assertions (behavior intentionally changed): Secret revocation and contact finalization
  keep every token fact except the spent `last_step_up_*` columns; the Secret name 254/255 cases and
  the revocation replay each get their own Step-Up. A contact `receipt_fault` keeps the evidence: the
  receipt failure rolls back the consumption and the exact retry finalizes through committed Source
  provenance without consuming.
- TDD order: the primitive was written before its test file; the HTTP rename-then-delete case was
  red against the pre-change behavior by construction (the delete returned 303) and is green now.

## Runs

- Narrow set (15 paths: the files above plus `passkey_mutation_concurrency_test`,
  `contact_registration_otp_bootstrap_finalizer_test`, `telephone_credential_registration_otp_finalizer_test`,
  `identity_passkey_registration_committers_test`, `step_up_resolver_security_mode_test`,
  `token_status_management_test`, `test/controllers/base/org/identity/{emails,telephones}`):
  256 runs, 0 F / 0 E twice in a row; one earlier run of the same set had 1 failure that did not
  repeat and was not captured (unidentified flake).
- Wide set (373 files mentioning `step_up`, excluding the Base OAuth/OIDC tests): 3592 runs,
  132 F / 331 E before the last two test fixes. Every failure inspected was an Auth admission 400,
  a redirect to `/sign`, or OIDC/sign-out (concurrent work); the only Step-Up related one
  (`BasePasskeyMutationStepUpTest`) was then updated and passes. No baseline without this change was
  run, because reverting the worktree is not allowed.
- `rubocop` on the 16 changed Ruby files: no offenses.

## Not done

- Target binding is enforced only where the requirement carries `resource_ref`; the settings
  callers pass `nil`, so their evidence is bound to the operation scope, not to one record.
- Not wired: Secret issuance chain (reservation, presentation, storage confirmation, reattempt,
  invalidation), social link/unlink, ORG enforcement cases, avatar ownership transfers, Base
  admission issuance and the generic `VerificationBase` before-action gates.
