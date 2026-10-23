# Sign-in flow columns left without a writer by the Local flow removal

Status: Open; recorded 2026-10-23 during WU-01 (D-60) of the 2026-10 authentication cycle. No change
is authorized by this entry.

## Facts (static reading after WU-01)

- `client_sign_in_flows`, `visitor_sign_in_flows` and `operator_sign_in_flows` keep
  `result_digest`, `result_generation`, `result_expires_at` and `base_finalized_at`.
- Their only writers were `prepare_local_result_delivery!` and the Base Local completion
  (`LocalAuthenticationSessionCommitter`), both removed in WU-01. Nothing in `app/` writes them now.
- `*_sign_in_flows_base_finalization_valid` still requires `token_id` and `result_digest` when
  `base_finalized_at` is set, so the column cannot be set without the retired result digest.
- Readers that remain: `CredentialSecurityTransition#revoke_authentication_admissions!` filters
  `base_finalized_at: nil` (always true now), and the session-limit paths
  (`BaseSignInLimitations`, `Base::App::Sign::In::LimitationsController`) refuse when
  `base_finalized_at` is present (never true now).

## To decide when selected

Remove the four columns, the CHECK and the dead reader conditions together, through a reversible
migration with an owner-approved recovery plan (`generic/migrations.mdc`). Update
`docs/mermaid/idp-*-sign-in-flow-evidence.mmd` and the storage topology in the same change.
