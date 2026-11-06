# Base Verification Setup Bootstrap Cannot Run In The Base RP Cell

Date: 2026-11-03

Status: Backlog. Found by Codex during unit 4 of `specs/op-mediated-step-up`; the owner decided to
handle it separately from that change. Not fixed. Not reproduced at runtime.

## Observation (source reading)

- `RuntimeRole::BASE_RP_PREFIXES` includes `verification`, so `base/{app,org}/verification/setups`
  is owned by `rp-base-<realm>-ww` (`lib/runtime_role.rb`). This predates the step-up change.
- In an RP cell process, `BrowserRpAuthentication#resolve_rp_cell_access` builds the access state
  with `security_context: nil`, so `current_session_token` is nil.
- `Base::App::Verification::SetupsController#bootstrap_permitted?` calls
  `current_session_token.established_authentication_method`, which would raise on nil.
- `Base::Org::Verification::SetupsController#create` passes `current_session_token` to
  `BaseStepUpAdmissionIssuer`, which accepts only an OP root token.

The bootstrap flow keeps a primary-login anchor on the OP root token, which an RP cell does not
hold.

## Open decision

Where the first-authenticator bootstrap belongs: an OP-mediated flow like the new step-up, an
OP-owned route, or another anchor. This needs its own contract and ADR amendment.

## Not verified

- Runtime behavior in a deployed RP cell.
- Whether the existing tests exercise the RP cell path or only the OP-chain path.
