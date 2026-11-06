# Base Features That Need The OP Root Token In The RP Cell

Date: 2026-11-04

Status: Backlog. Out of scope of `specs/op-mediated-step-up` by owner decision (review-9, R9-4).

When Base runs the RP cell path (any `rp-base-*` process, and under `shared` after O-12), there is
no OP security context, so `current_session_token` cannot supply the OP root token. These Base
features depend on it and are made to refuse explicitly until redesigned:

- Session listing and revocation: `identity/sessions`, `identity/revocations/others`, selectors.
- APP Secret: `secrets`, `secret_issuances`, `secret_presentations`.
- ORG `identity/secret_credentials`, `identity/removals`.
- Bootstrap (`verification/setups`): see `2026-11-03-base-verification-setup-bootstrap-rp-cell.md`.

Open decision: per feature, whether Base calls an authenticated OP owner endpoint (as proposed for
O-9) or the feature moves to an OP-owned surface. Source:
`specs/op-mediated-step-up/contracts/revision-13-design.md`, O-12 table.

## APP Secret restoration acceptance

The RP refusal is temporary. Restore the browser path only after its authenticated owner boundary,
RP-to-OP session binding, authorization and failure behavior are designed and accepted. The restored
browser integration tests must demonstrate all of the following with real RP sessions:

- A valid Step-Up event permits the owner's rename, Passkey-origin issuance, presentation and
  storage confirmation; the same unexpired event can be reused within its accepted scope of use.
- A signed return path or issuance target for another actor or browser session cannot disclose or
  mutate that actor's Secret or issuance, even when the requesting actor has valid Step-Up evidence.
- A missing, expired, revoked or mismatched event cannot authorize a Secret operation. A failed
  presentation or storage confirmation cannot expose or activate an unpresented candidate.
- A storage or owner dependency failure is reported as unavailable without falsely claiming a
  completed operation; rollback and audit outcomes remain observable and retry behavior is explicit.
- Retain meaningful public-boundary tests for these browser guarantees after restoration. The
  current owner-writer tests in `test/operations/client_secret_name_committer_test.rb`,
  `client_secret_revocation_committer_test.rb`, `client_secret_presentation_issuer_test.rb`,
  `client_secret_storage_confirmation_committer_test.rb` and
  `client_secret_passkey_reservation_issuer_test.rb` cover source ownership, evidence and lifecycle
  boundaries; they do not by themselves prove browser return-path and session isolation.

Until then, the RP must return a localized refusal and record the refusal reason without changing
credential or issuance state. `test/integration/step_up_authentication_test.rb` covers this current
behavior. The former OP-chain browser success cases cannot execute on the RP-cell route and are not
an implementation of the restored browser guarantees.
