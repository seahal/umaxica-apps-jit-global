# ORG Telephone management public links

Starting HEAD: `bfb1fb8880e443672caafd9fd0f5e75087cb97fe`. Application/tests/documentation have
uncommitted changes. Existing work and the intervening user checkpoint commit were preserved. This
record is neither independent acceptance nor a reproducible code snapshot.

After the preceding Gate 3 full Rails and Vitest recovery succeeded, a public HTTP test followed its
actual index-generated Telephone edit link. It failed for the intended reason: the public-ID link
returned 404 because the controller still queried its primary key. Red command:
`bundle exec rails test test/controllers/base/org/identity/telephones/registrations_controller_test.rb`;
exit 1, 32 runs, 237 assertions, one failure, zero errors/skips, 5.136591 seconds.

The controller now explicitly classifies a 21-character public identity separately from established
positive decimal PK URLs of at most 19 digits. Both lookups remain current-Operator scoped. A failed
public lookup never falls back to a PK. New edit/delete links carry public identity. Existing
numeric callers are a bounded ID-3b compatibility contract with consumer/cutover exit conditions,
not an external exception or permission for new remote bigint references. No routing/authentication
redesign, legacy OTP fallback or request-time ID generation was introduced.

Focused verification command:

```
bundle exec rails test test/controllers/base/org/identity/telephones/registrations_controller_test.rb test/integration/identity_settings_page_coverage_test.rb test/integration/sign/org/credential_removal_constraints_test.rb
```

First Green: 41 runs, 348 assertions, zero failures/errors/skips. After adding unchanged-security
regressions for foreign/public/legacy and malformed references through GET/DELETE, final focused run
exited 0: 42 runs, 383 assertions, zero failures/errors/skips, 10.042513 seconds. Foreign rows
remain owned by the original Operator and rejected deletion changes no row count. These public
boundary assertions supplement, rather than replace, existing numeric URL coverage.

RuboCop inspected controller and HTTP test: two files, zero offenses, exit 0. Oxfmt formatted the
checklist; `git diff --check` passed. The complete checklist diff is this task's ID-3b append only;
no pre-existing checklist content is staged under the owned-document commit permission.

Full `bundle exec rails test` and `bun run test` Gate 2 runs started against owned isolated fleet
`20261010p3d2`, complete twenty-DB preparation scope and workers 1. Vitest exited 0: 99 files, 1,140
tests, 13.41 seconds. Rails remains running. New feature editing is held until both results are
inspected. Existing-row backfill, NOT NULL/DB immutability and registration-session source-PK
retirement remain open. No production/shared operation, push or external delivery was performed.
