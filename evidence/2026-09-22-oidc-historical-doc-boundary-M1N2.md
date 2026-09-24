# OIDC historical-document boundary audit

Date: 2026-09-22
Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
Working tree: pre-existing local changes plus the current documentation-only amendment; no
commit, push, GitHub write, provider call, or external configuration change was made.

## Scope

The local OIDC registry and application call paths were searched for the retired shared browser
client IDs. No production Ruby/configuration call site remains for `sign-rp`, `base-rails-rp`, or
`side-rails-rp`; the canonical local registry retains only the seven surface-specific browser RPs
and the separately gated `core-next-rp` bridge compatibility registration.

Several superseded ADRs and migration documents still contained historical statements that could
be mistaken for current registration instructions. The current boundary ADR already defines the
accepted authority and registry contract. A short supersession note was added to the affected
architecture/security references so the historical material remains available without silently
reintroducing the retired clients.

## Verification

- Read-only repository search covered `app`, `config`, `lib`, `adr`, `docs`, `plans`, and `test`.
- `git diff --check` passed after the documentation amendment.
- No application behavior, route, client registry, migration, or external registration changed in
  this slice.
- The latest Compose-backed Rails verification remains the previously recorded
  `11531 runs, 73397 assertions, 0 failures, 0 errors, 8 skips` for the CF-010 result-generation
  guard slice; this documentation-only slice did not rerun Rails tests.

## Remaining boundary

External RP registration/key retirement, deployed callers outside this repository, and the live
`core-next-rp` bridge migration remain separate gates. This audit does not claim those external
conditions are complete.
