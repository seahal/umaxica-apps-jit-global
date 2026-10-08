# Ceremony proof shape cutover

Commit: `6405c465c82dd45625d294ad8f8c2fe7827a4390`; the worktree contains uncommitted changes. The
shared checkout changed through a checkpoint at 15:04:35 UTC, before this proof-shape track. The
implementing agent did not run commit/push/PR commands.

The two original Source JSON proof database tests now use independent signup and credential
registration issuers/verifiers and typed ceremony columns. Registration covers ORG as well as
APP/COM. Opaque UUID generations replace obsolete counter and JSON-version partitions; keyed
verifier sentinels/length/case, binding, finite deadlines, terminal erasure and microsecond
neighbors around zero and sixty-second receipt duration are retained on the current storage.

The first run produced six malformed-verifier failures and four missing canonical signup-reference
fixture errors (10 tests/54 assertions, seed 35989). Three generated CHECK migrations now require
well-formed pending/verified/cancelled proof and finite deadlines; required test reference records
use semantic model defaults. Local test Ticket migrations and constraint validation succeeded. No
existing records were rewritten and no production operation was performed.

The two migrated database tests plus finite-deadline, terminal SQL and receipt tests passed 40
tests/1,408 assertions, no failures/errors/skips, seed 43733. Infinite SQL deadlines now fail before
storage; the same public predicate rejects in-memory infinity, and actual transport and verification
refuse the unchanged original deadline. Scoped lint identified one line-length offense, subsequently
formatted; final lint disposition is recorded separately when executed.

An exact executable Ruby reference search found nine shared stateful signup/registration definitions
with no callers after the test cutover. Those Git-tracked definitions were removed locally,
recoverable from Git. Post-removal verification, legacy Source column retirement and whole-suite
verification remain required; no task completion is claimed here.

Post-removal verification subsequently passed 333 tests/5,577 assertions, zero failures/errors/
skips, seed 53772, using the two database test files, five original registration operation test
files and three original shared-ceremony test files, all now exercising the independent APIs. Final
scoped RuboCop passed the three migrated SQL test files. Legacy Source column retirement and final
comprehensive gates remain incomplete.

Each proof-shape CHECK migration was subsequently rolled back and reapplied by exact version on its
own local test Ticket database. The concurrency/lifecycle/operation-isolation/destination/ deadline
selection passed 54 tests/300 assertions, no failures/errors/skips, seed 61032, using the normal
sixteen workers. No shared policy, migration bypass or SQL exception fallback was added.

Test configuration disables automatic schema dumps after migration. Explicit Rails
db:schema:dump:app_ticket / com_ticket / org_ticket generated the three SQL dumps successfully; the
APP dump contains the new constraints, functions and triggers. No schema file was hand-edited.
