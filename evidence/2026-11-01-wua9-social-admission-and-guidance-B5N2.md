# Social callback admission and verified-subject guidance

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 370 tracked modified paths, 1
tracked deletion, and 73 untracked paths; there were no staged paths. Existing work was preserved
and no commit was created.

APP social login now retains the admitted Auth Ceremony session ID as provider-attempt correlation.
Before consuming OAuth callback state, the success callback compares it with the active ceremony
resolved from the current host-only `auth_sid`. The failure callback applies the same comparison. A
wrong-SID request receives the shared 409 response without consuming callback state, clearing the
social attempt, changing either ceremony, issuing a token, or setting Auth session/DBSC cookies.
This correlation does not grant admission or choose an actor.

The obsolete D-47 test expecting identical responses for verified registered and unregistered
provider subjects was updated to the later R-AU-23 / `two.md` §10.7 contract: verified crossings
receive the correct fresh-entry guidance, while the failed attempt is not reused. The integration
coverage checks both guidance cases and wrong-SID failure and success callbacks.

Verification performed:

- `test/integration/social_login_admission_test.rb` — 13 runs, 290 assertions, 0
  failures/errors/skips.
- The focused AC-53, R-AU-23, and unregistered-subject guidance selection — 3 runs, 58 assertions, 0
  failures/errors/skips.
- Normal admitted Google callback — 1 run, 46 assertions, 0 failures/errors/skips.
- Ruby syntax passed for the changed social controller/concern files and integration test.
- RuboCop passed for the 4 changed application Ruby files, with no offenses in the AC-53 test block.
  Full-file RuboCop reported 21 offenses in other portions of the already-modified integration test.
- `git diff --check` passed.
- A combined identity-authority guard and OAuth callback-state test command ran 11 tests and had one
  failure: `IdentityAuthorityInversionGuardTest` expects the Auth registration route source to
  include a `create` action, while the current source declares the entry resource as `show` and has
  separate registration-create routes. This route-source mismatch is outside this social callback
  change. The other test outcome is not separated by that combined command.
- No full suite was run; it remains reserved for final `two.md` closure.

Rails tests required three preference JWT environment variables at boot. They were loaded into the
test process from `.env.container.devcontainer` without printing values or changing that file; no
environment-construction test was added.
