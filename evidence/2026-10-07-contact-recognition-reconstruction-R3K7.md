# Contact recognition and empty-fleet reconstruction

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`.
- The worktree had inherited and current uncommitted implementation, migrations and tests.
- Scope: owned disposable PostgreSQL fleets only; no shared/production deployment or historical
  migration edits. No existing fleet was dropped or reset.

## Historical recognition

The new client/visitor forward migrations validate exact Source finalization/release intents or
durable completed signup proof. They preserve existing facts and OTP counters, require the owner,
and abort unknown history and effective owner/destination conflicts with non-secret row IDs.
Recognition uses one owning database timestamp. Reversal explicitly refuses to erase security facts.

`tmp/contact-recognition-probe-20261007.rb` executed public migration entrypoints in four owned
minimal-schema databases: 70 scenarios passed across app/com email/telephone, including incomplete
completion, unfinished signup, suspended/locked bindings, orphan owners, wrong owner/channel,
unknown release, immutable existing facts, conflicts and irreversible down. These are operational
migration probes, not Minitest setup tests or proof of the entire production schema.
An incomplete terminal signup scenario first failed, then passed after the guard was corrected.
Full-schema execution exposed the physical APP telephone column and VERIFIED ID differences;
metadata was corrected to `user_identity_telephone_status_id` and VERIFIED ID 1.

## Reconstruction failure and repair

Ordinary `bin/rails db:migrate` on fresh2 exited successfully but imported structure dumps.
Reference-data migrations were stamped without their rows: a focused test run had
97 runs, 269 assertions, 83 errors, no failures or skips. A bounded diagnostic replay of the existing
APP reference seed changed sign-in reference rows from 0 to 14 only in fresh2; this was not accepted
as a reconstruction fix.

Installed Rails DatabaseTasks initializes empty databases from available dumps unless
`migrate(skip_initialize: true)` is used. The manifest-guarded repository `db:test:prepare` now uses
that public API. Fresh3 was created separately with 20 absent-before-creation names, owned by root,
and the required isolated ownership comments; its manifest records OIDs 545725 through 545744.
The first actual reconstruction stopped at the inherited migration helper's undefined
`rp_device_foreign_key` local after extraction. Using the helper's actual `foreign_key` parameter
preserves the same validated constraint. Re-running preparation exited 0 without resetting data.

Catalog verification found current migration receipts in all 20 databases (search/storage have
zero migrations), 14 client sign-in states, and no removed empty-stub receipt `20261007124420`.
Both new Contact recognition guards applied on this real reconstruction. This verifies test-fleet
construction, not development/shared deployment, dump parity or Final Verification.

## Behavioral regression check

With the fresh3 manifest, `PARALLEL_WORKERS=1`, seed 42:

```bash
bin/rails test test/models/contact_binding_constraints_test.rb \
  test/adapters/otp_verification_budget_adapter_test.rb \
  test/services/sign_otp_ceremony_test.rb \
  test/controllers/auth/app/in/emails_controller_test.rb \
  test/controllers/auth/com/in/emails_controller_test.rb --seed 42
```

Result: **97 runs, 1,006 assertions, zero failures, errors or skips**. No other Rails test was
running at invocation. The initial broad failures above were environment-construction failures,
not ignored test failures. The complete suite, timing parity and Final Verification remain open.

The completed Contact DDL acceptance now also exercises direct writes that try to release a
pending Contact without recognition in each of the four tables. Re-running
`bin/rails test test/models/contact_binding_constraints_test.rb --seed 42` passed:
7 runs, 232 assertions, no failures, errors or skips. Scoped RuboCop inspected that file with
no offenses, exit 0. With these constraint boundaries, the 70 historical migration probes and
the true empty test-fleet reconstruction, Task 19.1 is checked. Task 19.2–19.4 and development
fleet/schema-drift Final Verification remain separate and unchecked.
