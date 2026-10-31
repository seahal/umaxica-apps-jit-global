# WU-A6 Standby scope normalization (operation-blind context)

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree carried the uncommitted
  WU-3..WU-7, WU-A1, and WU-A13 slices of this cycle plus these changes.
- Requirement: R-AU-10 of `two.md` section 3.8 with AC-41. The Standby (org emergency
  access) session context must constrain its issued scopes to exactly the same `scp` claims the
  same Operator's Normal session carries; withholding a scarce operation happens at that
  operation's Step-Up gate, and the `scp` claim must not become a second place where the same
  restriction can drift.
- Changed:
  - `app/values/authentication_context_value.rb`: `constrain_scopes` returns the context
    untouched for both `normal` and `standby`; only the fail-closed unknown context drops the
    capability-named scopes (`read:org`, `write:org`, `read:self`, `write:self`, now
    `CAPABILITY_NAMED_SCOPES`) and keeps the structural ones. The per-context read/write
    capability vocabulary was retired; the one session capability that remains is `step_up`.
  - `app/controllers/concerns/authorization_token_claims.rb`: the issuance comment block now
    states the same contract as the value (no behavior change at this call site, since it
    delegated to the value before).
  - `docs/security/org-emergency-access.md` capability-model section rewritten: no scope
    filtering for Standby, one mechanism boundary (Step-Up gates), and the inventory guard named.
  - `test/policies/standby_authentication_context_policy_test.rb` now mints the emergency claim
    set exactly as issuance does (unaltered scope plus `authn_ctx`).
- New guard `test/unit/security/authentication_context_operation_inventory_test.rb`: after
  eager loading, every concrete `ApplicationPolicy` descendant and every declared public rule is
  enumerated; Normal and Standby must decide identically on each rule, an unrecognised context
  must deny each rule, and the capability/scope vocabulary is pinned closed. First comprehensive
  run: 24,337 rule-level assertions, 0 failures.
- Public boundary results this slice:
  - focused WU-A6 set (context values, policy pre-check, continuity, emergency passkey
    ceremony, step-up prohibition, restricted-mode chrome, ceremony-sharing invariants, OIDC
    protocol verifiers, token/base-token scope readers, authorize service): 141 runs, 25,024
    assertions, 0 failures, 0 errors, 0 skips.
  - `bun run test` was already green earlier this cycle after the WU-A13 slice (96 files, 1052
    tests); no JavaScript surface changed in this WU-A6 slice.
  - RuboCop clean on all five touched files after style correction.
- Deliberately unchanged: Entra normal sign-in (untouched), the Step-Up prohibition layers
  documented in the same doc, the `authn_ctx` acceptance strictness on OIDC access tokens, and
  the `retired`-session lifecycle.
- Companion deliverable for the owner gate: `plans/2026-10-30-wu7-com-preference-shape-review.md`
  presents the WU-7 `com_setting` Before/After, the current measured baseline (dev store holds
  0 preference rows; test store 2, both `NOTHING`), the migration ordering and the recovery
  ticket contents required before any destructive com preference migration runs.
