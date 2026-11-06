# WU-A6 Standby Root issuance documentation status

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree already contained broad uncommitted changes, including earlier edits to
  `docs/security/org-emergency-access.md`; this slice preserves them.
- Source inspection confirmed that `SignOrgStandbyPasskeyCeremony#perform_passkey_sign_in` passes
  `AuthenticationContextValue::STANDBY_KEY` to `establish_signed_in_session!`. In OIDC-started
  ceremonies, `AuthenticationBase#pending_sign_in_result_after_primary!` delegates to
  `establish_oidc_authentication_evidence!`, which records evidence for later Root issuance.
  `Visa::Org::AuthorizationBaseController#login_for_oidc` passes
  `AuthenticationContextValue::NORMAL_KEY` to `log_in`.
- Updated `docs/security/org-emergency-access.md` to distinguish the Auth-side Standby evidence from
  the current Visa Root behavior and to state that the end-to-end Standby Root path is incomplete.
  Updated ignored local `four.md` to record this discrepancy.
- No application behavior or schema was changed. No test was run; this was a source/documentation
  correction. The exact ceremony-to-OIDC binding and its reviewed Root issuance behavior remain
  unimplemented and unverified.
