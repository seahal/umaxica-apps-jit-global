# Dead identifier destruction boundaries

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`.
The worktree contained uncommitted implementation changes affecting these results.

The ordinary destruction callback and dedicated channel purgers now share each channel's archive
writer, avoiding duplicate history creation. All six concrete models register their own callback.
Database PII, not unsaved caller PII, supplies the fingerprint. Existing legal holds and enforcement
guards are checked under the persisted owner lock. A later Email destruction refusal rolls back its
history insertion and exposes no successful archive receipt.

The added recoverable-row tests initially failed: `bin/rails test
test/models/dead_identifier_destroy_test.rb` produced 10 runs, 36 assertions, two failures, no
errors or skips. Ordinary destruction bypassed APP/COM scheduled retention. Independent Email and
Telephone guards now refuse destruction until the scheduled discard and purge deadlines mature.

After the fix, `bin/rails test test/models/dead_identifier_destroy_test.rb
test/operations/dead_identifier_purge_test.rb
test/operations/dead_identifier_purge_concurrency_test.rb` passed: 40 runs, 189 assertions, zero
failures, errors or skips. This includes all-realm direct destruction, repeated identifier reuse,
owner mismatch rejection, rollback and separate-connection duplicate-purge checks.

Earlier in this session, the same selection before the three added rollback/retention tests passed
37 runs and 173 assertions. The rollback-focused file separately passed eight runs and 34 assertions.
These overlapping selections are not additive totals.

Whole-owner withdrawal anonymization, bulk owner deletion and create-versus-purge concurrency are
not certified by these results. No production changes, commits, pushes or worktrees were performed.

Focused RuboCop passed for both archive concerns, both channel purgers and the destruction test
file after formatting corrections: five files inspected, no offenses. `git diff --check` passed.

The broader ORG registration plus retention-job selection initially produced 44 runs, 147
assertions, no failures and one error. The existing signup-cleanup test lacked both its cleanup
PENDING and flow CANCELLED reference rows. Its setup is unchanged at HEAD, and a read-only
`bin/rails runner -e test` probe confirmed the cleanup PENDING row was absent. Missing translation
masked the first invalid association; after supplying that reference, the database exposed the
missing CANCELLED FK. The test now supplies both reference classes' semantic DEFAULTS as test data.
Its focused rerun passed one run, four assertions, no failures, errors or skips. This corrects
pre-existing test-data prerequisites without weakening the cleanup assertions.

The complete broader selection was rerun after the setup correction:
`bin/rails test test/controllers/base/org/identity/emails/registrations_controller_test.rb
test/controllers/base/org/identity/telephones/registrations_controller_test.rb
test/jobs/retention_purge_job_test.rb` passed 44 runs, 151 assertions, zero failures, errors or skips.
RuboCop for the changed retention-job test passed (one file); `git diff --check` remained green.
