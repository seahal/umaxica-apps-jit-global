# Regional RP registration blocker

- Date: 2026-09-21 UTC
- Repository: `seahal/umaxica-apps-jit-global`
- Branch: `feature`
- HEAD observed: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: pre-existing uncommitted changes were preserved; no reset, clean, commit, GitHub
  write, provider access, or external configuration change was performed.

## Finding

The Frozen Plan's `FREQ-0014` requires independently registered JP/US browser RP identities,
including separate `client_id`, audience, exact redirect/logout/backchannel registrations,
private-key JWT credentials, and RP-session client bindings. The current accepted ADR explicitly
records this regional registration matrix as unresolved and blocks client IDs, redirect
registrations, external RP configuration, and legacy-session migration until that matrix is
approved and verified.

The current registry still defines one non-regional client per first-party face:
`core-app`, `core-com`, `core-org`, `side-app`, `side-com`, `side-org`, and `edit-org` in
`app/values/oidc_client_stores_static_client_store.rb`. It also retains the four deprecated
shared browser registrations because live application call sites remain in the Auth/Base
controllers and registry. Existing client key namespaces are shared at the surface level, for
example `CORE_APP`, `BASE_APP`, and `SIGN_APP`.

## Why implementation is blocked

Adding JP/US IDs locally would require choosing unapproved client names, redirect registrations,
audiences, private-key namespaces/credentials, host-to-region mapping, and migration behavior for
existing sessions. Reusing the current keys would violate the Frozen Plan's independent-credential
invariant. Removing the legacy clients before all real callers and external registrations are
verified would risk breaking active authorization and logout flows.

This is an authentication-boundary decision and an external-registration dependency, not a minor
implementation detail. No safe repository-only change can satisfy `FREQ-0014` without guessing.

## Evidence

- Frozen Plan `FREQ-0014`: `/tmp/umaxica-frozen-plan/frozen-plan.md` lines 557-558.
- Accepted ADR amendment: `adr/base-auth-ceremony-and-seven-rp-boundary.md` lines 121-123.
- Current registry: `app/values/oidc_client_stores_static_client_store.rb` lines 17-85.
- Current production call-site inventory: `app/controllers/auth/**`,
  `app/controllers/base/**`, and `app/values/oidc_client_stores_static_client_store.rb` still
  reference the shared IDs.
- The current execution context cannot access external registration or key-management systems,
  and none were contacted.

## Disposition

`FREQ-0014`: BLOCKED_BY_DEPENDENCY / PLAN_DEVIATION required before implementation.

No regional RP code, key reuse, legacy-client deletion, or external registration was invented.
The next safe decision must approve the JP/US registration matrix and migration/retirement order,
then provide repository-visible configuration and test fixtures for each independent credential.
