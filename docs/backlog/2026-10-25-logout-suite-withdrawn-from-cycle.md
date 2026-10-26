# Logout suite withdrawn from the 2026-10 authentication cycle

Status: Withdrawn from the cycle by the owner on 2026-10-25 (option A: freeze the current code, do
not revert). Not accepted. **The current logout code must not be deployed until this entry is
resolved** (see "Deployment").

Units: `two.md` WU-14 (RP-Initiated Logout), WU-15 (Back-Channel Logout), WU-16 (one OP
authority-stop primitive), WU-22 (sign-out records SO-1 … SO-7), WU-44 (root issuance re-check,
epoch, credential-change serialization). Gates: `three.md` G-16, G-19, G-20, A14-*, A15-*, A16-*,
A22-*, A44-*.

## What the cycle set out to do

- One durable, browser-independent OP authority-stop record per stop, written by a single
  primitive (`OpAuthorityStopCommitter`), with an explicit cause (`browser_logout`,
  `rp_initiated_logout`, `token_revocation`, `refresh_reuse`, `revoke_others`, `credential_change`,
  `identity_stop`, `administrative`, `risk`) and scope (`root`, `grant`, `all_roots_of_principal`)
  (D-27/BX-1, D-119, D-123, D-172, D-173, D-179 (3)).
- RP-Initiated Logout as specified by OpenID Connect; the RP no longer writes OP logout rows
  (D-33).
- Every participating RP notified through a durable Back-Channel Logout outbox delivered by Solid
  Queue (D-26, D-29, D-31, D-117, D-118, D-121).
- Sign-out records with NOT NULL principal and cause, `ON DELETE RESTRICT` token references and a
  purge order (D-43, D-123; G-20).
- A Root is never issued from authority that a concurrent stop has already withdrawn: final
  eligibility check, authoritative epoch, credential-change serialization on the principal lock
  (D-163 … D-167).
- Removal of the legacy logout and sign-out flow storage (D-168, D-179 (2)).

## What exists in the worktree today (uncommitted on top of `bde2346c1`)

- `OpAuthorityStopCommitter` and the authority-stop tables, per realm
  (`db/op_base_{app,com,org}_migrate/20261025120000` … `20261025120301`).
- Legacy tables dropped by irreversible migrations: `*_logout_flows` (`20261025120100`) and
  `*_sign_out_flows` (`20261025120400`); refresh delivery receipts removed (`20261025100100`).
- BCL sender, outbox and receiver; registered-RP logout matrix and Edit RP return tests pass
  (`evidence/2026-10-25-wu15-16-22-suite-check-C7M4.md`,
  `evidence/2026-10-25-edit-rp-logout-return-A6Q2.md`).
- Eight legacy logout/refresh test files were deleted with the code they covered; their protective
  properties were mapped to remaining tests, except that the mapping was done by reading only.

## Why it stalled

1. **Dead legacy path still live.** `AcmeLogoutTransaction` is no longer created anywhere
   (`AcmeLogoutTransactionCoordinator.persist_transaction!` has no caller), yet the Auth sign-out
   controllers on APP/COM/ORG and `SignOutCancellation` still look it up and advance it
   (`app/controllers/auth/*/sign/outs_controller.rb`, `app/controllers/concerns/sign_out_cancellation.rb`).
   D-33 says the RP no longer writes it. Model, table and readers remain.
2. **The definitions describe the pre-change design.** `two.md` R3/V9 assume a Visa
   `LogoutReceipt` and `/sign/bye`; the stop primitive (D-172, D-173) and the record removal
   (D-179) changed the shape afterwards. `three.md` A22-1 tests the removed sign-out-flow models.
   G-16 requires a read-only `GET /sign/out/completion`; Base still routes a completion while Auth
   tests assert the Auth completion route is retired. `two.md` is layered ("Part 6 wins over
   earlier sections"), so the current contract is not readable in one place.
3. **Decisions not carried into code.** COM and ORG Secret removal does not go through
   `CredentialSecurityTransition`, so the D-167 `credential_change` stop may not happen there.
4. **Design checked after the fact.** The D-173 cause mapping did not check the allowed scopes per
   cause; the defect surfaced as test errors and was fixed by D-179 (3). Deleted tests were mapped to
   replacement coverage only afterwards.
5. **Acceptance not run.** A14-1 … A14-7 and A44-1 … A44-10 are "Not run" in `three.md`; A15-7 is
   unverified; A16-5 was blocked by a stale test database (since reset, not re-run); A22-4 and G-16
   are unverified. The concurrency cases (logout vs refresh, logout vs rotation,
   commit-then-disconnect, old logout after-work vs new login) are untested.

## What to do next (proposed order)

1. Inventory the current implementation: every logout entry point, record, notification and
   cleanup step, per surface and host (Base RP, Auth, Visa OP, Jump), as one diagram. Read-only.
2. Diff that inventory against `one.md`, `two.md`, `three.md`, the ADRs
   (`adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md`,
   `adr/visa-op-host.md`) and `docs/mermaid/`. List every disagreement.
3. Decide each disagreement with the owner (see below).
4. Write one consolidated definition and acceptance set for the logout suite, replacing the layered
   sections; restate G-16/G-20 against the current design; retire A22-1.
5. Implement, then run the acceptance, including the two-connection concurrency cases of A44.

## Decisions the owner must make

- Remove `AcmeLogoutTransaction` (model, coordinator, table, Auth sign-out readers), or define what
  it is still for.
- Where sign-out completion lives (Base, Auth, Visa) and whether `GET /sign/out/completion` stays.
- Whether the Visa `LogoutReceipt` / `/sign/bye` design of `two.md` R3/V9 is still the target.
- Whether COM/ORG Secret removal is a `credential_change` stop (D-167), as APP credential removals
  are.
- Whether WU-44 (Root issuance vs concurrent stop) stays coupled to the logout suite or is
  scheduled as its own unit.
- Whether the irreversible table drops (`*_logout_flows`, `*_sign_out_flows`) ship with the frozen
  code or wait for the redesign.

## Deployment

Do not deploy the current worktree's logout changes as-is. Before any deployment that includes
them, at least:

- the full suite has no failure in logout, BCL or authority-stop tests;
- G-16 and G-20 are verified against the current design;
- the irreversible drops are approved with row counts and a recovery plan (AGENTS.md);
- the dead `AcmeLogoutTransaction` readers are resolved.

If the rest of the cycle must ship first, the logout changes need to be separated from it at that
time; the owner decides how.

## References

`one.md` D-26, D-27, D-29, D-31, D-33, D-34, D-43, D-117 … D-123, D-163 … D-168, D-172, D-173,
D-179; `two.md` WU-14, WU-15, WU-16, WU-22, WU-44, Part 6; `three.md` G-16, G-19, G-20;
`evidence/2026-10-25-wu15-16-22-suite-check-C7M4.md`,
`evidence/2026-10-25-wu15-16-22-op-authority-stop-6B3Q.md`,
`evidence/2026-10-25-edit-rp-logout-return-A6Q2.md`.
