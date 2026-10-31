# WU-7 receipt strict-loading regression

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; staged, unstaged and untracked changes affected the result.
- The six com preference child-destruction tests reported by the full suite were reproduced: each errored because its existing explicit association preload omitted the newly added receipt. The lifecycle purger already preloads the receipt. Updated the model test's child preload set and extended the child-deletion case to create and verify removal of a receipt.
- Before the change the targeted deletion selection had 6 errors. Afterward `PARALLEL_WORKERS=1 bin/rails test test/models/com_preference_test.rb test/jobs/preference_lifecycle_job_test.rb` passed: 37 runs, 120 assertions, zero failures, errors or skips. This includes the existing refusal to destroy a preference with Chronicle history. RuboCop passed after a formatting-only adjustment.
- This corrects those test setup failures and verifies the public model/job paths exercised; it does not change the production strict-loading policy. Other full-suite failures, reset audit, OpenAPI, the JWT type discrepancy and WU-7 completion remain unresolved. No migration was run.
