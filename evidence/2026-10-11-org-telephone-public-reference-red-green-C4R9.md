# ORG Telephone public candidate reference

HEAD: `b4d5aa563900f784cb8085a4a6ff69fe38abeddd`. Application, migration, tests and documentation
are uncommitted alongside pre-existing work; this record is not an independent acceptance or a
reproducible implementation snapshot. All execution used owned isolated run `20261010p3d2`, host
`primary`, workers 1, complete twenty-database preparation scope.

The new public issuer test failed for the intended reason: the ticket candidate reference length was
1 rather than 21.
`bundle exec rails test test/operations/telephone_credential_registration_otp_issuer_test.rb` exited
1 with 7 runs, 65 assertions, one failure and no errors/skips.

Rails generated `20261011002402_add_public_id_to_operator_telephones.rb`. The additive migration
creates a nullable varchar(25), unique concurrent B-tree index and nonblank unvalidated CHECK.
`bundle exec rails db:migrate:org_zenith` exited 0 on the owned fleet. No existing row was
rewritten, no trigger permission was expanded and no shared/production database was changed.

OperatorTelephone now uses the existing PublicId issuance mechanism. Issuer, resend, form query,
verification, finalizers, SMS producers and queued delivery compare/resolve its public identity. ORG
delivery binding requires an opaque 21-character candidate, without numeric-PK fallback. Local
controller PK URL/session consumers remain pending, as do existing-row operational backfill, NOT
NULL/check validation and DB immutability. ID-3a records these limits independently of evidence.

The first integration run found the existing numeric-only delivery validator (21 errors); after
updating the validator it found one remaining old numeric expected tuple. The binding fixture also
initially used 22 characters rather than 21 and failed explicitly. All were corrected without
removing assertion boundaries. Final focused command:

```
bundle exec rails test test/operations/telephone_credential_registration_otp_issuer_test.rb test/controllers/base/org/identity/telephones/registrations_controller_test.rb test/models/operator_telephone_test.rb test/values/contact_registration_otp_delivery_binding_value_test.rb
```

Exit 0: 63 runs, 637 assertions, zero failures/errors/skips, 5.795377 seconds. Coverage includes
actual ORG registration HTTP and queued transport guards, plus binding format/sentinel boundaries.
The current transition inventory now says opaque public candidate rather than numeric candidate; no
lifecycle state or authority boundary changed.

`git diff --check` passed before final documentation formatting. Oxfmt formatted the two affected
checklist/inventory documents. Initial RuboCop reported duplicate case branches and parentheses;
these were consolidated/corrected. The remaining binding test lint was rerun: one file, zero
offenses, exit 0.

Both `bundle exec rails test` and `bun run test` full Gate 2 commands have started. Vitest exited 0
with 99 files and 1,140 tests, 13.33 seconds. Rails is still running; no further feature slice may
begin until both results are inspected and any new regression repaired. Application/migration/test
changes remain uncommitted under the limited owned-document commit permission. No push or external
sending occurred.
