# OP-only consume lock candidates

- Date: 2026-11-04
- Full git HEAD: `b30345216886c98af1f04cbd434f067f12decf01`
- Worktree: extensively modified and uncommitted; this source review and documentation update were
  performed in that state.
- Scope: the invitation and logout transaction row-lock candidates in the O-10 lexical scan.

`OrganizationInvitation#consume!` locks its OP ORG invitation row. Its only service caller is
`OrgRegistrationPolicy#consume!`, with no production caller found for that policy method.
`OrgOperatorLifecycleInvitationAcceptance` validates an invitation and then returns the
migration-required refusal before consumption. `LogoutTransaction#consume!` locks its OP APP row;
neither the model consumer nor `consume_one_time_url_token!` has an application callsite. The
inspected methods do not acquire a Client / Operator principal row. This is a bounded source
finding; future caller composition is not covered.

The reproducible intersection of
`rg -l 'with_lock|\.lock\b|lock!|with_cycle_lock' app --glob '*.rb'` and
`rg -l 'OpBase|ClientStepUpCeremonyTransaction|OperatorStepUpCeremonyTransaction|ClientOidcAuthorizationTransaction|OperatorOidcAuthorizationTransaction|ClientAuthCeremonySession|OperatorAuthCeremonySession' app --glob '*.rb'`
still yields 88 files. Comparing full paths with the updated
`specs/op-mediated-step-up/contracts/lock-order-inventory.md` yields 13 named and 75 unnamed. The
unnamed files are a triage set, not confirmed inversions.

No tests, database operations, or runtime operations were performed.
