# Source proof fixture cutover

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; the worktree contains uncommitted changes.

The actual APP/COM Email/Telephone settings binding-fault HTTP matrix and independent Email
bootstrap finalizer tests no longer reconstruct or inspect Source HOTP. They recover the code
from the actual encrypted delivery job and check ceremony consumption, fixed receipt deadlines,
Source rollback and exact retry. The two-file normal Rails command passed 42 tests and
1,180 assertions, no failures/errors/skips (seed 37314). Scoped RuboCop passed both files.

The Client/Visitor/Operator Email model and Email concern fixture selection initially ran
104 tests and 310 assertions, with one obsolete pre-finalization uniqueness expectation
(seed 55587). The updated test checks effective binding uniqueness at finalization. The next
selection ran 104 tests, 316 assertions, no failures, one error and no skips (seed 64919).
OTP migration cases passed; the selection is not GREEN.

Read-only follow-up located the teardown FK failure in `test_app_zenith_db_0`: Telephone 335
references missing Client 980190964 and predates this fixture slice (04:26 UTC). The Email race
creates no Telephone; its new Client ID collides with the old orphan. This is an environment/data
failure, not evidence of an OTP production regression. The unrelated Telephone was not deleted:
the orphan-deletion approval covers only VisitorEmail 212 and 214. No primary-key workaround or
global fixture/helper modification was added. Its remediation remains outside that deletion scope.

Full Rails, full lint and final architecture/security gates remain unverified. The model selection
failure remains visible, and final acceptance has not been marked complete.
