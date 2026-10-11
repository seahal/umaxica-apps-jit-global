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

## Subsequent read-only catalog and consumer inspection

At documentation HEAD `dc581749cd8be237b6330f344bd35a15a1d472b1`, with the same uncommitted
implementation, a normal Rails runner inspected the owned fleet's actual PostgreSQL catalog. The new
column is character varying(25), nullable; the public_id index is B-tree, unique, valid and ready.
The nonblank CHECK is not yet validated. This proves additive shape, not final ID-4 acceptance. No
catalog mutation or data output occurred.

Read-only inspection additionally found that TelephonesController generates an edit link using the
model (now public-ID to_param), while edit/destroy still find by primary key and the delete link
explicitly passes id. Registration session lookup also retains the source id. These producer and
consumer inconsistencies require a subsequent scoped Red/Green slice after the running full gate;
they are not treated as permanent exceptions or accepted completion. The Rails process remains live
and its result remains pending. No new application edits occurred during this inspection.

## Full gate found an obsolete numeric expectation

The full Rails command exited 1: 15,014 runs, 127,310 assertions, one failure, zero errors/skips,
1,026.880759 seconds. The sole failing target was TelephoneTest's typed-ceremony issuance assertion
in `test/models/concerns/telephone_test.rb:28`, which still expected `@telephone.id.to_s`. Actual
issuance returned the candidate's public identity. The earlier baseline had no failures; this gate
is not a PASS or evidence of global completion.

The assertion now requires equality with public_id and separately rejects the numeric PK. This is an
approved ID-3 contract correction, not an assertion deletion or dual-format acceptance. Gate 3 holds
all new feature editing until the focused set and both full suites have completed successfully. The
focused recovery set adds the formerly failing concern file to all four prior focused files. Its
result and the required recovery full gates are not yet claimed.

Focused Gate 3 recovery completed with exit 0: 88 runs, 732 assertions, zero failures/errors/skips,
6.110964 seconds. The exact command was:

```
bundle exec rails test test/models/concerns/telephone_test.rb test/operations/telephone_credential_registration_otp_issuer_test.rb test/controllers/base/org/identity/telephones/registrations_controller_test.rb test/models/operator_telephone_test.rb test/values/contact_registration_otp_delivery_binding_value_test.rb
```

RuboCop checked the corrected concern test: one file, zero offenses, exit 0. Both recovery full
commands (`bundle exec rails test`, `bun run test`) started on the same owned fleet and dirty
implementation. Their completion is pending; no next feature editing has begun.
