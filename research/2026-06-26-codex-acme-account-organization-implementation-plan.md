# Acme Account / Organization Implementation Plan Notes

## Context

This memo records the current repository state and the unresolved implementation questions around
Acme Account / Organization bootstrap.

## Scope

- Natural-person organization scope only.
- No corporate organization, legal entity, billing, contract, or representative-verification work in
  this plan.
- No STI or enum `kind` / `type` modeling in this plan.
- No account / organization / unit code changes in this docs freeze.
- All three Acme surfaces remain in scope as parallel contracts; they should not be merged into one
  surface-specific rule.

## Observed

- `Enterprise`, `Bureau`, and `Company` each already expose `public_id` and `to_param` via the
  shared `PublicId` concern.
- Acme routes use ordinary plural resources for `accounts`, `organizations`, and `avatars`; they do
  not use `param: :public_id`.
- Current Acme controllers resolve resource identifiers through `params[:id]` and look up by
  `public_id`.
- `Persona` still carries `moniker` and `Organization` still carries `name`; `title` is not
  implemented yet.
- `IdentityGraphProvisioner` delegates sign-up finalization to `AcmeSelectorBootstrapAuthority`.
- `AcmeSelectorBootstrapAuthority` already provisions the Acme bootstrap graph inside a single
  transaction.
- The current bootstrap shape creates the RP account, identity, account, collective, root unit,
  membership, and avatar-related artifacts in one coordinated flow.
- The current account binding shape is still 1:1 at the principal/account boundary.
- Quota enforcement for accounts per identity and organizations per identity is not implemented.
- `OrganizationUnit` is currently created as part of the existing bootstrap flow, and the root unit
  behavior is already established.
- Legacy `Organization` naming collides conceptually with the new Acme Organization resource, so
  docs should distinguish the concrete model from the planned public resource.

## Why It Matters

The repository already contains most of the mechanical pieces needed for the intended Acme model,
but the long-term direction is not yet captured cleanly in the implementation plan:

- the current 1:1 binding must be distinguished from the target 1:n direction;
- `title` should be introduced without forcing an early rename;
- quota should stay out of model validation;
- preference authority needs a separate ADR update if the older docs still describe the wrong owner;
- the new resource plan must keep the three Acme surfaces aligned without merging their concerns;
- OrganizationUnit should stay untouched until its own scope is decided.

## Open Questions

1. Identity 1:n Account

- The current model is effectively 1:1 at the identity binding boundary.
- Moving to 1:n will require association changes and likely unique index changes.
- Option A: loosen identity-binding uniqueness and allow multiple bindings. Reject this because it
  preserves the wrong boundary.
- Option B: hang multiple Accounts directly under the principal and keep identity binding as login /
  OIDC binding. Reject this as an ownership model, though it may still be useful as a future lookup
  convenience.
- Option C: keep 1:1 for now and defer the redesign.
- Option D: introduce `AccountAssignment`, `AccountGrant`, or an equivalent join model so access can
  be granted by an Identity with the right organization role.

2. `title` introduction

- Add `title` first rather than renaming `moniker` / `name` in place.
- Account title and Organization title must use separate validation code paths.
- Initial validation is ASCII alphanumeric only, 1 to 10 characters, with no spaces, symbols, or
  Japanese characters.
- Shared concern, shared validator, shared constant, or generic `ShortTitle` / `DisplayName`
  abstraction should not be introduced.

3. Quota direction

- Target limits are 10 Accounts per principal and 2 Organizations per principal.
- Put quota logic in policy, quota object, or service guard layers.
- Do not hardcode the limits in controllers or model validations.
- Whether suspended, deleted, withdrawn, or otherwise inactive rows count toward quota is still
  open.

4. Preference authority

- The current direction is Acme read-write and other surfaces read-only.
- Older ADRs may still describe a different authority split.
- That conflict needs a separate ADR update and should not be mixed into this account plan.

5. OrganizationUnit

- This memo intentionally does not define a new Unit design.
- The current root unit bootstrap behavior should remain intact until a separate decision is made.
- `OrganizationUnit` is intentionally excluded from the current implementation surface, including
  route, API, transfer, and delegation changes.

## Notes For Later Implementation

- Preserve the current bootstrap transaction and idempotency boundary.
- Keep `IdentityGraphProvisioner`, `AcmeSelectorBootstrapAuthority`, and `AcmeSelectorSurfaceConfig`
  as the existing bootstrap stack.
- Treat title support as additive and migrate callers gradually.
- Describe signup bootstrap as creating the initial organization, account, and initial
  assignment/grant rather than as Identity owning an Account.
- Keep `moniker` and `name` as legacy fields until a later rename or removal decision.
- Record any future choice to make Account 1:n in a separate ADR and separate PR, preferably with an
  assignment / grant model instead of an ownership model.
- Keep preference authority conflicts visible in docs until a dedicated ADR resolves them.

## Promotion Candidate

This memo should be promoted into implementation PR notes and task slicing when the next change is
ready to touch models, migrations, or bootstrap code.
