# Explicit visibility and architecture ratchet

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`.
Uncommitted implementation, generated baseline and test changes affected these results.

The three-file architecture/cop/invariant check failed three cases (24 runs / 610 assertions,
seed 7904): newly resolved files retained in the baseline, above-baseline implicit visibility,
and the Avatar legacy ownership guard matching unrelated SecretCredential owner columns.

A read-only complete measurement identified 29 over-limit visibility files. Their affected public
interfaces were made explicit, without moving callbacks, changing state, granting new authority,
changing transport or modifying private methods. This includes existing receiver `create` actions,
browser-RP metadata, repository interfaces, credential inventories, lifecycle predicates and typed
grant interfaces. All ten receiver-controller diffs add only `public :create`; nineteen further
application files likewise change visibility declarations only.

The ratchet then passed its no-increase test but correctly failed on resolved stale entries
(three runs / 2798 assertions, seed 32503). A complete measurement against the recorded counts
explicitly refused any increase before `bin/rails architecture:baseline` regenerated the two
artifacts. That normal generator recorded 91 concern-hook offenses / 91 files and 2973 implicit
visibility offenses / 1304 files. No baseline limit was raised to hide implementation debt.

Verification:

- RuboCop: ten receiver-controller files passed; nineteen other changed application files passed.
- `bin/rails test test/tooling/architecture_baseline_test.rb
  test/tooling/umaxica_architecture_cops_test.rb test/models/acme_logout_transaction_test.rb
  test/models/concerns/device_sessionable_test.rb test/services/step_up_requirement_test.rb
  test/services/sign_up_step_gate_test.rb test/policies/sign_up_step_gate_refusals_test.rb`:
  **45 runs / 2946 assertions, zero failures/errors/skips**, seed 14961. An initial setup error
  (seed 52018) was fixed by installing the test's semantic cleanup references; no assertions changed.
- Related HTTP command with `test/controllers/base/oauth_oidc_authority_test.rb`, three realm
  logout controller files, `test/integration/social_completion_cross_host_csrf_test.rb` and
  `test/controllers/concerns/branch_coverage_batch17_completions_and_emails_test.rb`:
  **118 runs / 532 assertions, 17 failures, zero errors/skips**, seed 34055. GET receiver form
  versus legacy redirect expectations and logout transport/CSRF expectations remain unresolved.
  Visibility-only changes do not change those responses; the failures predate this slice, but
  whole-goal attribution/contract reconciliation is not certified.

The Avatar guard remains failing; neither a broad exception nor assertion relaxation was added.
Full Rails, full RuboCop and all final gates remain incomplete. No migration, remote mutation,
production database or secret operation occurred in this slice.
