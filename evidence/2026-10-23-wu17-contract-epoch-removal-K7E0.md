# WU-17: remove client activation and `contract_epoch`; `authentication_epoch` NOT NULL (D-35, D-168)

Commit: `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72` with the uncommitted cycle changes (after WU-01, WU-20).

## Changes

- Removed:
  - `OpClientAdmissionGate` (authorize and token endpoints);
  - `OpClientAdmissionQuery`, `OpClientActivationWriter`, `Op*ClientActivation`;
  - `Op*ProtocolEpoch`, `ContractEpochValue`, the `umx_contract_epoch` claim (minting and RP
    verification), `rp_cell_contract_epoch` / `UMAXICA_RP_CONTRACT_EPOCH`;
  - the Refresh contract-epoch check;
  - the `contract_epoch` writes on roots, grants and RP sessions.
- `authentication_epoch`:
  - It is written explicitly at root issuance and grant creation, and the model validates it as an
    integer ≥ 0.
  - Refresh rotation now copies it to the replacement row. Before this change the replacement had
    NULL; the old NULL-as-0 reading hid that.
  - NULL handling is removed from `AuthenticationEpochValue.root_current?` and
    `OpIdentityEventInvalidator`.
- Migrations (D-168 authorization):
  - OP app/com/org `2026102313000{0..3}`: drop tables `op_client_activations` and
    `op_protocol_epochs`, drop `contract_epoch` on tokens, grants and OIDC transactions, backfill
    NULL `authentication_epoch` to 0 as a separate data step, then NOT NULL plus a `>= 0` CHECK
    added unvalidated and validated in the following migration.
  - Each of the 12 RP databases `2026102313000{0,1}`: drop `rp_sessions.contract_epoch` and narrow
    the shape CHECK.
  - The table drop is irreversible by design (recovery = rebuild from migrations; D-168 accepts the
    loss). Every other step has a `down`.
  - Applied to development and test databases. Structure dumps were edited by hand for these
    objects only.
- Tests:
  - 2149 + ~90 direct token/grant creations pass `authentication_epoch: 0`, added by script.
  - Epoch-only cases deleted: Refresh contract-epoch cutover, pre-R5 RP tokens, the floating
    epoch claim, the NULL-epoch root.
  - New: rotation keeps epochs 0 and 3.
  - Locale attribute names and docs/env mentions removed.

## Runs

- Full suite: 18424 runs, 58 F / 1 E (59 names). One name is not in G-1:
  `Auth::App::Sign::In::ChallengesControllerTest` destroy-without-MFA. It is order-dependent and
  passes in isolation and with the suite seed. Its fallback flow lookup is now limited to flows the
  test created; that run was not repeated in the full suite.
- `rubocop` on changed files: clean.

## Not verified

The production migration path (no deployment); the A17 identity-stop request tests beyond those
already in the suite.
