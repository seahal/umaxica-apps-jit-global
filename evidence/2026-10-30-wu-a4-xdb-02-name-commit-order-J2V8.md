# WU-A4 XDB-02 passkey-name commit order fix

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree carried the uncommitted
  WU-3..WU-7, WU-A1, WU-A6, WU-A13 and WU-A14 slices of this cycle plus these changes.
- Requirement: the XDB-02 row of the `two.md` §6.2 operation ledger (`two.md` WU-A4): "T消費→
  Z名称＋監査" — the op_base Step-Up consumption commits first, then the zenith rename and its
  audit commit — with the "第1commit直後 / 第2commit前後" failure windows named in §6.2.
- Defect found: the old body nested the zenith actor transaction inside the op_base token
  transaction, so on success the zenith rename + audit committed while the op_base outer
  transaction was still open and the consumption committed last. A failure at the consumption
  commit after the zenith commit left a renamed passkey with an unspent Step-Up proof; a failure
  inside the zenith branch left the T consumption rolled back and the zenith branch open
  instead of two sequential self-contained commits.
- Refactored `app/operations/identity_passkey_name_committer.rb` into ledger order:
  1. op_base authorization phase — session and token locks, evidence lock, ownership re-read
     through both realms' owner field, scope re-verification and the unchanged-description
     short-circuit that returns without spending anything (kept all four pre-existing refusal
     messages and the no-op contract);
  2. the self-contained `consume_step_up_evidence!` commit (`TokenStatusManagement` lock and
     clear);
  3. one zenith transaction carrying the rename and `PasskeyAuditOutbox` together. After the
     consumption commit every failure path raises the same `Denied` channel, so the lifecycle
     caller never reports a rename; the ledger's recovery is a fresh Step-Up.
- Public boundary tests added (`test/operations/identity_passkey_name_committer_test.rb`),
  both surfaces (app and org):
  - a zenith-side failure injected after the consumption commit (stubbed
    `PasskeyAuditOutbox.record_for!`): the token's step-up evidence is cleared (spent), the
    description stays "Original", no audit row exists, and the operation raises `Denied`;
  - an uncommittable consumption (stubbed `consume_step_up_evidence!` raising
    `StepUpEvidenceUnavailable`): the description, the audit count and the token's step-up
    evidence are all unchanged, and the operation raises `Denied`.
- Results:
  - `bin/rails test test/operations/identity_passkey_name_committer_test.rb test/operations/passkey_mutation_authorization_test.rb test/operations/passkey_mutation_concurrency_test.rb test/integration/base_passkey_mutation_step_up_test.rb`:
    15 runs, 179 assertions, 0 failures, 0 errors, 0 skips (the integration file is the
    controller-path 401 boundary for both surfaces).
  - RuboCop clean on both touched files after style correction.
- Not established by this slice: the remaining XDB-01, XDB-03..12 ledger rows, the cross-DB
  ordering for the same-commit boundaries of `identity_email_preference_committer`,
  `identity_totp_*`, `client_secret_*`, `identity_social_ceremony_*`, and the
  **two-connection barrier concurrency tests** that pin both commit orders under races
  (§12.6's separate-connection plan). The next slices should follow the same
  verify-fix-inject pattern one row at a time.
