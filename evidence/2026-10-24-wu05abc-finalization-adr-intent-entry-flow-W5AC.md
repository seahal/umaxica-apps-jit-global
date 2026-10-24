# WU-05a / WU-05b / WU-05c

Commit: `ba570a0007b1d40eabe32990a34831317fd98a93`, with this cycle's uncommitted changes in the
worktree.

## WU-05a: ADR and characterization

- New `adr/sign-up-finalization-in-auth.md`, indexed in `adr/README.md`. It records:
  - D-69 U1–U6, D-105, D-128 and D-131;
  - the Auth/authority split;
  - the decisive principal commit before the curfew;
  - canonical Sign In First for Google and Apple;
  - supersession of the social-commit-at-Base parts of
    `adr/sign-up-authentication-handoff-and-social-rt.md`.
- It is written before any WU-05d…g code (A05-1). Nothing is committed yet, so commit order is still
  the owner's to keep.
- **A05-5 characterization** ("existing social user signing in is never treated as sign-up"):
  - Tests: `SocialAuthLoginTest` "Google/Apple sign up entry with existing identity falls through to
    sign in flow", "… login with existing identity does not create new user", and
    `OmniauthCallbacksTest` "should sign in with existing Google user".
  - All of them are in the G-1 baseline as red. Run here, the two sign-up-entry cases still fail (2
    runs, 2 F).
  - Per the WU-05a stop rule these are known, expected-red cases. The cause is the G-1 session
    fixation containment (finalized OIDC result reissuance removed). They were not changed.

## WU-05b: effective intent on sign-up pages

Already delivered by WU-24b (`evidence/2026-10-23-wu24b-effective-entry-intent-I4B6.md`):
`AuthEntryIntentResolver` is the single decision point from server state. No change was needed.
WU-24's tests cover the refusal of a sign-in admission on sign-up pages (D-73 uniform 400).

## WU-05c: one social Flow per attempt, created at the entry

- `Auth::App::Omniauth::OmniauthCallbacksController`:
  - The callback no longer creates a Sign-up Flow. It uses only the Flow bound to the admitted
    Binding (`current_social_sign_up_flow`), and refuses with `invalid_intent` when there is none.
  - Removed: `create_pending_social_sign_up_flow!` and the dead D-71 path
    (`handle_social_sign_up_intent`, `create_social_sign_up_flow!`, `bind_social_sign_up_flow!`,
    `with_social_sign_up_lock`, `store_social_sign_up_sequence_id`, `social_sign_up_required?`).
    None had a caller.
- New test in `test/controllers/auth/app/social/ceremony_entry_test.rb`: "a sign-up callback without
  its entry Flow is refused and creates no Flow".
  - Setup: Switch, the Google sign-up entry, then the entry's Flow deleted.
  - Result: the callback answers 400 (ownership mismatch); Flow and Client counts are unchanged.
  - The test log shows `sign.signup.ownership_refused`.

## Runs

- `test/controllers/auth/app/social/ceremony_entry_test.rb`: 5 runs, 0 F.
- Social batch (13 files and directories): 113 runs, 21 F, 0 E. Every failure is in G-1; none is
  new.
- `rubocop` on the changed files: no offenses after autocorrect.
