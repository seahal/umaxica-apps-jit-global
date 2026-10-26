# WU-38: stuck sign-up registration report (D-180)

- Commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`.
- Worktree: dirty, with staged and unstaged changes. The focused tests ran against this HEAD plus
  this WU-38 work and unrelated existing worktree changes. The retention job file also contains
  unrelated concurrent changes; they were preserved. Immediately before this evidence file was
  created, `git status --short --untracked-files=all` listed 880 entries. Nothing was staged or
  committed for this follow-up.
- Contract: WU-38 follow-up scratch `codex-wu38-stuck-registrations.md`, `one.md` D-180, `two.md`
  WU-38, and D-125's Flow retention rule. No migration.

## Implementation

- Added `SignUpStuckRegistrationReportQuery`, which reads APP and COM principal, email, telephone
  and Flow identifiers on each model's reading role with writes prevented. It refuses an explicit
  writer-role caller. It returns only public identifiers, case names and cleanup attempt counts; no
  contact value is read. It detects (a) an unfinished principal or pending contact without a
  matching Flow and (b) a non-completed terminal Flow with pending/failed cleanup at 10 or more
  attempts. Registered principals and completed cleanup are excluded; 9 attempts are below the
  threshold. ORG is rejected because its current operator status and Flow schema cannot express the
  unfinished-registration predicate or retry counter.
- `RetentionPurgeJob` runs the query after its cleanup and retention work and emits one
  `sign_up.stuck_registrations.reported` event, or one `sign_up.stuck_registrations.report_failed`
  event if either surface query fails. Events group records by surface/case and include counts,
  public identifiers and attempt counts. Failures contain only surface and error class; they do not
  interrupt the job. The structured payload uses the key `groups`: `JitLogEvent`'s redactor treats
  keys containing `rt` as sensitive, so a `reports` key would be filtered.
- The retry sweep stops at the cap, but the retention purge previously could physically remove a
  failed terminal Flow after its shorter retention deadline. The APP/COM purge paths now preserve a
  non-completed terminal Flow until cleanup completes; completed registrations and cleaned terminal
  Flows remain eligible under the existing deadline. This keeps a capped Flow diagnosable and
  preserves the existing cleanup release path without adding a deletion or state transition.
- Added `docs/operations/stuck-sign-up-registration-runbook.md`. A diagnosed capped terminal Flow
  may be passed once to the existing `SignUpArtifactCleanup.call(cycle:)` operation. A missing-Flow
  case has no safe existing release entry point; it remains held and must be escalated. Updated
  `docs/security/sign-up-sequence.md`, AUTH-21 in `docs/checklists/authentication.md`, the WU-38
  status in `two.md`, D-180 in `one.md`, and appended this follow-up to the original WU-38 evidence.
  No lifecycle transition diagram changed.

## Verification

- `bin/rails test test/queries/sign_up_stuck_registration_report_query_test.rb test/jobs/retention_purge_job_test.rb test/jobs/sign_up_expiry_job_test.rb test/jobs/sign_up_curfew_cleanup_test.rb test/services/sign_up_artifact_cleanup_test.rb test/services/sign_up_artifact_cleanup_atomicity_test.rb` — 53 runs, 285 assertions, 0 failures, 0 errors, 0 skips. This covers APP/COM isolation, email/telephone orphans, writer refusal, ORG refusal, retry counts 9/10/11, in-progress and completed cleanup, registered principal exclusion, event ids/counts and PII absence, report failure without interrupted cleanup, and retention of capped Flows on both surfaces.
- `bundle exec rubocop app/queries/sign_up_stuck_registration_report_query.rb app/jobs/retention_purge_job.rb test/queries/sign_up_stuck_registration_report_query_test.rb test/jobs/retention_purge_job_test.rb` — 4 files inspected, no offenses.
- `git diff HEAD --check` still reports only pre-existing blank lines at EOF in
  `db/op_base_app_structure.sql:5050` and `db/op_base_com_structure.sql:3903`; these SQL files were
  not changed for WU-38. No full-suite run was made.

## Remaining limits

- A `flow_missing` row cannot be released through the existing Flow cleanup operation; no manual
  deletion or state write was added. Keep it held and escalate for separately reviewed remediation.
- ORG is not queried or emitted as an empty result because its schema has no corresponding case.
- The full Rails suite was not run.
