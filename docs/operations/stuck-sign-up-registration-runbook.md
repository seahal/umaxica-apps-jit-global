# Stuck Sign-Up Registration Runbook

This runbook covers stuck APP and COM registrations reported by
`RetentionPurgeJob`. Reporting is read-only. A report never releases or changes a registration.
ORG is not included because its operator acquisition schema has no equivalent unfinished status or
sign-up cleanup attempt counter.

## Find and Read a Report

Search the deployed application logs for either structured event name:

- `sign_up.stuck_registrations.reported` — the APP and COM queries completed. Each report group has
  `surface`, `case`, `count` and `registrations`; each entry in `groups` lists public identifiers and
  `cleanup_attempts_count` where a Flow exists.
- `sign_up.stuck_registrations.report_failed` — one or more surface queries failed. The event names
  failed surfaces and error classes. It may include results from a surface whose query succeeded;
  it is not evidence that a failed surface has no stuck registrations.

The event does not contain email addresses, telephone numbers, names or birthdates. `RetentionPurgeJob`
runs every 15 minutes and reports after its cleanup and retention work. A query failure is logged
without stopping that work.

The report comes from `SignUpStuckRegistrationReportQuery`, which uses the reading role and refuses
an explicit writing role. It reports:

- `flow_missing`: an unfinished principal or pending contact has no matching sign-up Flow. The
  attempt count is not applicable because no Flow exists.
- `cleanup_attempts_exhausted`: a terminal Flow is still in pending or failed cleanup after at least
  `SignUpArtifactCleanup::MAX_CLEANUP_ATTEMPTS` attempts (currently 10). Nine attempts are below the
  report threshold; ten and above are reported.

## What an Operator Does

Do not run Ruby on a production host to inspect or repair sign-up attempts (no `bin/rails runner`,
rake task or console session for this purpose; owner decision D-196, 2026-10-26). For either case,
open an incident with the surface, case, public identifiers and `cleanup_attempts_count` from the
event, and escalate to the sign-up owner. Do not copy contact values into logs, tickets or evidence.
Do not infer current state from an old event; later reports show whether the registration is still
stuck.

A `cleanup_attempts_exhausted` Flow is not retried by hand. Changing the cleanup itself is a
reviewed code change.

## `flow_missing` Has No Safe Release Entry Point

There is no Flow for the cleanup operation to act on. Do not create or restore a Flow, write status
values directly, or delete the principal/contact manually. Keep the contact held and escalate to the
sign-up owner for a separately reviewed remediation path. The current implementation
deliberately leaves this case unresolved rather than guessing which dependent artifacts are safe to
remove.

## ORG

ORG operator acquisition has no `UNVERIFIED_WITH_SIGN_UP` equivalent, and
`OperatorSignUpFlow` has no cleanup status or attempt counter. The report query therefore rejects
`:org`, and the job does not log an empty ORG result. Do not interpret absence of an ORG report as a
zero count.
