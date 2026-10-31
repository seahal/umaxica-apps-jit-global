# WU-7 com browser binding storage cutover

Commit: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the result.

After the user's database reset and requested full test run had applied the additive binding migration to the test database, com consent and Web Push reads and writes were switched from the legacy consent-child digest to `com_preference_browser_bindings`. No destructive migration or data cleanup was performed. Existing values in the legacy digest column are not copied or used by the new read path.

Before the change, the binding model, Web Push API, and retired-consent tests passed: 16 runs, 130 assertions. After the change, those tests plus the binding concern, Web Push initialization and preference response-binding integration tests passed with `bin/rails test`: 44 runs, 432 assertions, no failures, errors, or skips. They cover matched and mismatched binding, expiry, rollback, reuse of one browser binding across distinct preference rows, and a Web Push read without a consent child. RuboCop passed on the changed Ruby files checked.

The fixture-based journey and binding-read tests initially ran separately with 3 failures in consent and signed display reads; all three were also reported by the earlier full suite. The fixture-based tests built incomplete preferences without the option reference rows needed for display repair. After setting up those reference rows and updating the expiry assertion to use the database clock, the same files passed: 38 runs, 271 assertions, no failures, errors, or skips. A separate-connection binding/retirement race, legacy data recovery, the destructive schema cutover, realm key separation and the complete WU-7 acceptance remain unverified or incomplete.

The previously failing `ComPreferenceBrowserBinding` NOT NULL validation contract was rerun by name: 1 run, 2 assertions, no failures, errors, or skips. The new model validates digest presence explicitly.
