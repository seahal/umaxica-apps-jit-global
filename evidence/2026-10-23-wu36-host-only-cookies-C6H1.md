# WU-36: every cookie host-only

- Date: 2026-10-23. Base commit `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`; change uncommitted.
- Decisions: D-115, D-58; P-141 adopted by D-158 (no legacy Domain-cookie deletion exception).

## Change

- `CoreCookieOptions.for` no longer accepts `domain:` / `surface:` / `rails_env:` and never sets
  `Domain` or `Partitioned`. `CoreCookieDomain` and its tests are deleted.
- Callers updated: authentication cookies, preference cookies and the JS-readable consent mirror
  (previously apex-scoped), the consent buffer, withdrawal and enforcement-recovery ceremony
  cookies, the RP browser credential contract.
- Removed `PreferenceBase#clear_legacy_preference_auth_domain_cookies!` and
  `#preference_domain_cookie_deletion_options` (P-141: nothing was deployed, so no browser holds a
  production Domain cookie).
- Tests rewritten to the final contract: no environment sets `Domain` or `Partitioned`; the mirror
  cookie is host-only; auth deletion options carry no `Partitioned`.
- Docs: `adr/session-token-hardening-baseline.md`, `adr/invalid-browser-credential-recovery.md`,
  `adr/README.md`, `docs/vendor/identity/04_cookie-session-token-matrix.md`.
- Incidental: `plans/backlog/2026-10-21-production-credentials-key-name-mismatch.md` wording changed so
  `Security::AcmeRenameInventoryTest` (a G-1 baseline failure introduced by that cycle file) passes.

## Verification

- Cookie options, cookie security invariants, cookie service, Base preference cookie controllers,
  Core browser API boundary, rename inventory: 74 runs, 0 failures.
- Withdrawal and recovery ceremony tests plus the above: 129 runs, 0 failures.
- `grep -rn "CoreCookieDomain" app lib config`: empty (A36-2). RuboCop clean.
- A36-1 is covered by the option-level tests above; a per-endpoint `Set-Cookie` sweep was not added.
