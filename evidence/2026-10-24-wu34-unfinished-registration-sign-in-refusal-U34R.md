# WU-34: Sign In refuses unfinished registrations (D-106, D-128)

Commit: `ba570a0007b1d40eabe32990a34831317fd98a93`, with this cycle's uncommitted changes in the
worktree.

## AX26 first

- `test/models/unfinished_registration_login_test.rb`, run before the change: 2 runs, 1 F.
  - An APP Client in `UNVERIFIED_WITH_SIGN_UP` passed the Sign In predicate (`login_allowed?` was
    true).
  - The gap was confirmed at predicate level, as expected (static reading).
- The HTTP-level AX26-1 (abandoned telephone sign-up, then Passkey sign-in) and AX26-2 (abandoned
  email sign-up, then email sign-in) journeys were **not** run as request tests. The refusal is
  asserted at the shared predicate that every Sign In issuance and evidence point uses.

## Change

- New `Identity#sign_in_allowed?` = `login_allowed?` plus the class's
  `UNFINISHED_REGISTRATION_STATUS_IDS`:
  - Client: `[UNVERIFIED_WITH_SIGN_UP]`;
  - Visitor: `[UNVERIFIED_WITH_SIGN_UP]`;
  - Operator: none.
- The four Sign In checks in `AuthenticationBase` use it: `log_in` commit, pending-result after
  primary, OIDC evidence and its locked re-check.
- `login_allowed?` itself is unchanged. Sign-up operations use it for their own pending principal,
  so blocking the status there broke registration; that attempt was reverted.
- The sign-up handoff now passes the reloaded actor. The in-memory actor read before Finalization
  still showed the unfinished status.
- **COM (D-128):**
  - Migration `db/com_zenith_migrate/20261024100000_add_visitor_registration_statuses.rb` adds
    `VisitorStatus` 4 (`UNVERIFIED_WITH_SIGN_UP`) and 5 (`VERIFIED_WITH_SIGN_UP`). It was run on
    development and test, and its version was added to `db/com_zenith_structure.sql` by hand.
  - No existing Visitor row was moved: development data is volatile under D-168.
  - COM email and telephone candidates are created `UNVERIFIED_WITH_SIGN_UP`.
  - The COM email Finalization and `SignComUpTelephoneRegistrationFinalizer` promote the Visitor to
    `ACTIVE` through `Visitor#promote_finished_registration!` (the decisive commit, D-131).
  - The COM sign-up OTP issuers, guards, committers and form query expect the pending owner in
    `UNVERIFIED_WITH_SIGN_UP`, like APP.
  - `SignUpArtifactCleanup` retires COM dependents only while the Visitor is still unfinished.

## Tests

- `unfinished_registration_login_test.rb` after the change: 4 runs, 0 F (APP and COM, unfinished
  vs registered).
- 16 COM sign-up OTP, cleanup and finalizer test files built the COM candidate as `ACTIVE`; they now
  use `UNVERIFIED_WITH_SIGN_UP` (201 runs, 0 F).

## Runs

- **Full suite (full-23):** 18454 runs, 56 F / 2 E.
  - The only new name against G-1 was `LifecycleDirectStateWriteInvariantTest` (a direct status
    write in the COM finalizer).
  - It was fixed by moving the write into `Visitor#promote_finished_registration!`; the invariant,
    the COM finalizer and the COM controller tests then gave 266 runs, 0 F.
- No full run was repeated after that fix.
- `rubocop` on the changed files: no offenses.
