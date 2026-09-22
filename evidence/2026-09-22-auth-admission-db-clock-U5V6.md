# Auth admission writer-clock boundary

- Date: 2026-09-22 UTC
- HEAD: `277673d13547d722fc88f830711eee69b923a7e8`
- Scope: align Base authorization-transaction expiry checks during Auth admission with the
  established writer-database clock contract.
- Worktree: existing changes were preserved. This slice changed the shared Auth admission concern
  and its public integration regression test; no migration, schema, configuration, or external
  service was changed.
- External writes: none; no GitHub, AWS, Cloudflare, provider, production, shared database, email,
  or SMS service was contacted.

## Change

`AuthCeremonyAdmission` now evaluates both the login-challenge expiry and the authorization
transaction expiry using the matching transaction class's `database_now`, which reads the writer
database clock. The admission remains surface-bound, one-shot, and ceremony-only; no Base Browser
Session or RP authority was added.

The public admission regression creates a transaction whose stored expiry is in the future relative
to the application clock but in the past relative to the writer-clock value supplied by the
transaction model. It verifies that Auth rejects the admission without creating ceremony state.

## Verification

- Ruby syntax for the changed concern and test: PASS.
- Scoped RuboCop: PASS; 2 files inspected, no offenses.
- `git diff --check`: PASS.
- Rails test execution: UNVERIFIED in this shell. The required preflight stops before Rails boot
  because `primary` cannot be resolved; no fallback host, mock, or test weakening was used.

This is a local clock-consistency hardening slice. It does not close the `CF-010` cross-store
issuance/recovery blocker.

