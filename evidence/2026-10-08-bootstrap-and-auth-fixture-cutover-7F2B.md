# Bootstrap and Auth fixture cutover

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; the worktree contains uncommitted changes.

The actual Base APP first-Email bootstrap tests use encrypted delivery and the original typed
credential ceremony instead of identifier HOTP. Wrong code leaves the challenge pending; success
erases its active verifier and consumes proof without issuing Root freshness. The signin resend
tests now snapshot all identifier attributes, remove unused Source secrets, and retain independent
candidate/budget checks. AuthenticationBase's unused Source-expiry branch and its sole caller's
false option are removed; current Auth ceremony validation remains intact.

The four-file bootstrap/resend/auth-booster/signup-Root selection passed 33 tests/394 assertions, no
failures/errors/skips, seed 52106. COM signup's earlier 404 was a missing canonical recovery
credential Kind reference, identified through a temporary exception-class/stack observer and removed
afterward. Test-local semantic Kind/Status defaults fixed the original journey.

The seven-file signup/cancellation/Secret/Email-controller selection ran 71 tests/2,926 assertions,
zero failures, one error and zero skips, seed 57030; it is not GREEN. The error was an APP Telephone
effective-owner collision with owner 980190964. Read-only follow-up on test_app_zenith_db_0
confirmed Telephone335 is effective and that its owner is absent. Its number did not match
repository fixed test literals, so synthetic provenance is not asserted and the row was not deleted.
Prior deletion permission covered only VisitorEmail212/214; a narrow additional question was sent.
No production data or unrelated row was changed.

The earlier test commands used the starting commit above. The later read-only orphan check used
`6405c465c82dd45625d294ad8f8c2fe7827a4390`; the shared checkout's checkpoint occurred at 15:04:35
UTC. The implementing agent did not commit, stage, push or mutate GitHub.

Scoped lint passed the four bootstrap/Auth files and the APP signup Email controller. Whole-suite
and comprehensive gate verification remain incomplete.
