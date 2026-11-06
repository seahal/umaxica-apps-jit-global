# WU-A8 RP logout path audit

- At HEAD `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`, the RP logout launcher revokes the local RP
  session before clearing local credentials, submits only the Refresh Token bound to that session,
  and builds the Visa end-session request without `id_token_hint`. The RP logout controllers do not
  read `logout_hint` or `id_token_hint`.
- `BrowserRpAuthentication` still selects the OP grant-chain path when `rp_cell_process?` is false;
  its shared-role branch reads OP grant/session state and refreshes at the OP token endpoint. This
  is a separate WU-A8 gap from the RP logout launcher.
- Updated `docs/security/logout-sequence.md`, `docs/security/logout-session-management.md`, and the
  2026-11-01 amendment note in
  `adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md` to state
  those distinct current behaviors.
- `test/integration/rp_cell_local_session_readiness_test.rb` passed: 20 runs, 305 assertions, 0
  failures, 0 errors, 0 skips. It covers RP-cell readiness and logout for the selected cells; it
  does not establish the shared-role authentication contract or close WU-A8.
- A focused source search found no `logout_hint` or `id_token_hint` references in the RP logout
  launcher/controllers. `git diff --check` passed. The repository worktree was already heavily
  modified and uncommitted; no commit was created.
- No full suite, migration, external Visa call, or production/Neon operation was run in this slice.
  WU-A8 and the broader `two.md` work remain open.
