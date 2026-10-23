# WU-44: Root issuance re-check under the principal lock; authoritative epoch

- Date: 2026-10-23. Base commit `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`; change uncommitted.
- Decisions: D-163, D-165, D-167 (part). Inventory: `two.md` 6.14.

## Change

- `AuthenticationBase#commit_login_session_under_actor_lock`: after `resource.lock!` (reload) the
  administrative lock and `login_allowed?` are checked again; a refusal returns `:access_locked` /
  `:login_forbidden` and creates no Root. The only Root creator remains `create_login_token_record`.
- `AuthenticationEpochValue.root_current?`: `root_epoch == actor_epoch` (was `>=`); the legacy `nil`
  branch stays until WU-17's NOT NULL.
- `OidcAccessTokenAuthenticator`: reads the actor on the **writer** (was `:reading`) and refuses a
  root whose epoch is not current. `AuthenticationCurrentResourceResolver` (browser root
  authentication, already on the writer) refuses such a root with `:authentication_epoch_stale`.
  Token exchange and refresh already compared the epoch under the actor lock.
- `docs/backlog/2026-10-22-pre-stop-jwt-accepted-after-operator-restore.md` narrowed.

## Verification

- `test/controllers/concerns/root_issuance_recheck_test.rb` (A44-1, deterministic form): the actor
  object is loaded before an administrative lock + epoch bump commits; `log_in` then refuses with
  `:access_locked` and creates no `ClientToken`. **Red without the re-check** (temporarily removed:
  1 token created), green with it. Second case: without a stop the Root carries the current epoch.
- `test/services/oidc_access_token_authenticator_test.rb` (A44-3): after the identity stop the old
  Access JWT is refused without the OP-side invalidation, and stays refused while the account is
  active.
- `test/values/authentication_epoch_value_test.rb` (A44-8): equal / one lower / one higher;
  missing epoch at zero / non-zero.
- Epoch-related suites: 124 runs, 0 failures.

## Not done / Not run

- D-167 second half: re-validating the credential state under the lock in `log_in` for a credential
  change committed while a login waits. `CredentialSecurityTransition` already revokes other roots
  under the actor lock (verified), but a login that verified the old credential and acquires the
  lock after the change still creates a Root. Closing it needs a per-method credential-version fact
  compared under the lock; not built in this unit.
- A44-2 (stop after insert → revoked by the invalidator), A44-4 (replica lag), A44-5 (writer down),
  A44-6, A44-7 (static guard), A44-9, A44-10: not run.
