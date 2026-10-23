# WU-01: entry-less Local Sign-in Flow removal (D-60)

Commit: `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`, with the uncommitted changes of the 2026-10
authentication cycle (WU-03 … WU-44 recorded in their own evidence) in the worktree.

## Removed

- Routes and controllers: Base `/sign/completion` and Auth `/sign/handoff` (app/com/org) with
  `BaseLocalAuthenticationCompletion` and `AuthLocalResultHandoff`; `continue_selector_sequence!`
  (D-64).
- `BaseAuthAdmissionCoordinator`: `issue_local_entry!`, `restart_local_flow!`,
  `LOCAL_ENTRY_PURPOSE`, `LOCAL_SIGN_IN_FLOW`, `local_entry_purpose(_for|?)`, and the
  `:sign_in_flow` admission parent everywhere (`AuthAdmissionBinding`, the coordinator,
  `BaseCeremonyBindingConfirmation`, `AuthAdmissionBindingPurger`).
- Purposes `local_sign_in`, `local_sign_up`, `local_sign_in_result` (ceremony session, binding,
  `OpaqueAdmissionStore`).
- Local branches: `AuthenticationBase`, `AuthenticationSequenceGate`, `AuthCeremonyContext`,
  `AuthCeremonyAdmission`, Auth `Sign::InsController` (app/com/org), APP Secret controller,
  APP/COM MFA Passkey controllers, Base social sign-up completion, `ClientSecretCredential`,
  `ClientSecretSignInReceipt`, `ClientSecretClaimFinalizer`, `ClientSecretClaimCommitter`
  (`authorization_transaction:` is now required), `AuthEmailOtpChallenge` (OIDC parent only).
- `LocalAuthenticationResultCoordinator`, `LocalAuthenticationSessionCommitter`, and the result
  delivery methods of the flow concern. `record_local_authentication_evidence!` is kept and
  renamed `record_authentication_evidence!` in `SignInFlowAuthenticationEvidence`.
- Schema (owner decision D-168): migrations `2026102312000{0,1,2}` drop
  `*_auth_admission_bindings.sign_in_flow_id`, `*_auth_ceremony_sessions.local_sign_{in,up}_flow_ref`
  and rewrite the parent/purpose CHECKs; `2026102312000{3,4,5}` validate them. Rollback of the app
  pair and re-apply was run on the development database and succeeded. Structure dumps edited by
  hand for these objects only (a full dump reformats unrelated CHECKs under local PostgreSQL 18).

`grep -rn "local_sign_in\|local_sign_up\|issue_local_entry\|sign/completion\|sign_handoff" app lib config`
returns nothing.

## Deviations from the WU-01 contract

1. Column removal was done in WU-01, while two.md said "do not drop it in WU-01". The owner's later
   D-168 authorizes destructive persistence changes; the migrations are reversible.
2. Two OIDC behaviors changed. The contract says to keep OIDC behavior byte-for-byte, but these
   were gaps that had only been covered by the Local branch:
   - `establish_oidc_authentication_evidence!` raised `InvalidTransition` (HTTP 500) when the flow
     was halted, advanced or re-owned during MFA. It now returns `invalid_request` under the same
     locked phase/principal/expiry/ceremony checks the Local branch used.
   - `CredentialSecurityTransition` halted only flows referenced by a Local ceremony. It now
     halts every unfinished flow of the actor, including OIDC MFA-phase flows.
   - An Auth credential ceremony without an OIDC parent is refused instead of reaching `log_in`
     (root issuance on Auth) or `authenticate!`.
3. `SignInPhaseViolationEnforcer` lazily loaded `flow.principal` on a strict-loading flow. That was
   reachable only once a principal-bound flow met a contradictory binding (OIDC MFA phase). The
   principal is now read explicitly.
4. Step 3 (Red before removal) was not run in that order. The refusal tests
   (`test/integration/routes/retired_local_sign_in_route_test.rb`, the retired-purpose cases in
   `test/models/auth_ceremony_session_test.rb` and `auth_admission_binding_test.rb`) were added after
   the removal and pass.

## Tests

Re-pointed: 69 files moved from `issue_local_entry!` to `OidcTestEntry.issue!`. **Assertions
changed** where the OIDC parent differs from Local:
- No primary-phase phase binding (`fb`).
- Evidence is read from the ceremony or the actor's newest flow.
- Missing MFA state redirects to `/sign/in` (303) instead of 409.
- An MFA interruption returns to Auth `/sign/in` instead of Base `/sign`.
- OIDC deadlines: `login_challenge_expires_at`.

These are behavior statements of the OIDC path, not the Local one.

Deleted with the Local code (no OIDC counterpart is claimed by this record):
- Local-subject tests:
  - `test/controllers/base/local_authentication_entry_test.rb`
  - `test/integration/local_authentication_boundary_test.rb`
  - `test/integration/{,com_}session_limit_promotion_flow_test.rb`
  - `test/controllers/auth/app/sign/in/checks_authorization_test.rb`
- 6 cases of `test/integration/root_login_establishment_flow_test.rb`. **Coverage gap:**
  "credential change after Auth completion rejects the outstanding result at the Base root
  boundary" has no OIDC equivalent identified.
- The Local cases of:
  - the coordinator, transition and limitations tests
  - the social authentications test
  - the Secret result-delivery tests
  - ORG emergency "Base finalizes emergency evidence" (via `/sign/handoff`): **standby session
    issuance through OIDC is unverified by this record.**

New: `test/support/sign_in_flow_test_factory.rb`. `OidcTestEntry.issue!` no longer swallows unknown
keywords; the callers that relied on `restart_of:`/`nonce_digest:` were fixed.

## Runs

- WU-01 set (67 files after deletions): 996 runs, 1 failure. That failure,
  `Social::AuthenticationsControllerTest` result-delivery outage, is in G-1.
- Test databases were rebuilt from migrations (as in G-1) because residue from repeated runs, with
  no `security` Chronicle retention policy seeded by any migration, produced order-dependent
  `ChronicleRetentionPolicy` errors.
- Full suite after rebuild: 18439 runs, 57 F / 2 E (59 names), then 58 F / 1 E (59 names, seed
  35397). Against G-1 (77 F / 2 E), each run has one extra failure, different each time, and each
  passes on rerun:
  - `AuthCeremonyRevocationConcurrencyTest` APP cleanup race.
  - `RpBackchannelLogoutReceiverTest` signed Logout Token (3/3 passes alone).

  Recorded as flaky, not fixed.
- `rubocop` on all changed Ruby files: no offenses.

Follow-up: `docs/backlog/2026-10-23-sign-in-flow-local-result-columns.md` (writerless
`result_*` / `base_finalized_at` on sign-in flows).
