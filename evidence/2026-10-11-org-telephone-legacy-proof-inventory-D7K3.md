# ORG Telephone legacy proof inventory

HEAD: `ff0a5e2e4ba38c6fac77ce9c6eec8218187646df`. Application, query, task and test changes remain
uncommitted alongside unrelated source-policy work. Tests and direct CLI validation used the owned
twenty-DB fleet `20261010p3d2`, complete preparation list and workers 1. This is observed
implementation evidence, not independent acceptance or production cutover approval.

ID-3a/ID-3d require observing old registration proof before consumer cutover. The new read-only
query accepts only an explicit OperatorTelephoneCeremonyTransaction relation. It returns aggregate
pending-parent, deliverable-proof and unexpired-receipt counts using database time, excluding
current 21-character candidates. It does not mutate bindings, reissue proof or expose PII/proof
values. Counts are not a distributed snapshot or proof of writer/queue quiescence.

The initial public interface returned empty counts. Behavioral Red reported 1 run, 1 assertion, 1
failure, no errors/skips: a live numeric-bound registration expected count 1 but observed 0. After
implementing aggregate queries, two test-description execution errors used an unsupported Integer
microsecond convenience method. They were corrected to exact Rational one-microsecond offsets; those
errors are not valid Red. No production expiry rule was relaxed.

Final focused command:

```
bundle exec rails test test/queries/operator_telephone_legacy_reference_inventory_test.rb test/operations/operator_telephone_public_id_backfill_operation_test.rb
```

Exit 0: 9 runs, 73 assertions, zero failures/errors/skips, 1.057643 seconds. Tests preserve row
attributes, cover a consumed receipt after OTP challenge expiry, receipt and parent deadlines
immediately before/at/after the boundary, an all-digit current 21-character candidate and rejected
other realm/channel or absent scopes. The successful backfill regressions remain in this run.

RuboCop formatting/explicit-visibility findings were corrected only in the new files. Final
`bundle exec rubocop app/queries/operator_telephone_legacy_reference_inventory.rb test/queries/operator_telephone_legacy_reference_inventory_test.rb lib/tasks/operator_telephone_public_ids.rake`
exited 0: three files, no offenses. The real
`bundle exec rake org_telephone_public_ids:legacy_references` call exited 0 with all three counts 0
in the isolated fixture-time database. That observation does not establish production counts or
cutover readiness. ID-3d and the existing DB workflow link the actual query/test/task.

Gate 2 `bundle exec rails test` and `bun run test` started against this code state. Vitest exited 0:
99 files, 1,140 tests, 13.42 seconds. Rails remains running; no next feature may begin before its
result is inspected. No shared/production database, external delivery, application-code commit or
push occurred. Source NOT NULL, DB immutability, controlled writer/queue drain and final cutover
remain incomplete.
