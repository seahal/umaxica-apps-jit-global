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

The query can be run directly for a current read-only view:

```sh
bin/rails runner 'pp SignUpStuckRegistrationReportQuery.call(surface: :app)'
bin/rails runner 'pp SignUpStuckRegistrationReportQuery.call(surface: :com)'
```

The query uses the reading role and refuses an explicit writing role. It reports:

- `flow_missing`: an unfinished principal or pending contact has no matching sign-up Flow. The
  attempt count is not applicable because no Flow exists.
- `cleanup_attempts_exhausted`: a terminal Flow is still in pending or failed cleanup after at least
  `SignUpArtifactCleanup::MAX_CLEANUP_ATTEMPTS` attempts (currently 10). Nine attempts are below the
  report threshold; ten and above are reported.

## Diagnose Before a Release

Use the `surface` and `flow_public_id` from the report. For a Flow, inspect the existing WU-26
diagnosis inventory:

```sh
bin/rails runner 'pp SignUpAttemptDiagnosisInventory.call(surface: :app, flow_public_id: "FLOW_PUBLIC_ID")'
```

Use `:com` for a Visitor Flow. A `flow_missing` record has no Flow id, so the WU-26 Flow inventory
cannot inspect it; use a fresh `SignUpStuckRegistrationReportQuery` result to confirm the current
public identifiers. Do not infer current state from an old event. Do not copy contact values into
logs, tickets or evidence.

WU-26 also accepts one of these surface-local selectors:

```sh
bin/rails runner 'pp SignUpAttemptDiagnosisInventory.call(surface: :app, entry_reference_digest: "DIGEST")'
bin/rails runner 'pp SignUpAttemptDiagnosisInventory.call(surface: :app, principal_public_id: "PRINCIPAL_PUBLIC_ID")'
bin/rails runner 'pp SignUpAttemptDiagnosisInventory.call(surface: :app, provider: "google", subject_digest: "DIGEST")'
```

Use `:com` for COM Flow or principal lookup. Social subject lookup is APP-only because COM has no
social sign-up Candidate. The entry digest uses the existing SHA-256 reference algorithm over
`reference:<entry-reference>`; the social digest is produced by
`IdentitySocialCeremonyContract.provider_subject_digest`. These commands accept only the digests,
never the raw entry reference or provider subject. Each call requires exactly one selector. A
well-formed unknown selector returns `flow_not_found`; a selector that matches multiple Flows
returns every diagnosis under `multiple_attempts_found`. The report includes OIDC transaction and
result state, ceremony session lifecycle timestamps, social Candidate ids/states, audit event ids
and names, request ids, and a structured-log search key. It omits contact references, raw provider
subjects, transaction secrets, session digests, and outbox payloads.

## Release Case `cleanup_attempts_exhausted`

An operator may retry cleanup once, after all of these checks pass:

1. A fresh report query still returns the Flow as `cleanup_attempts_exhausted`.
2. The WU-26 diagnosis confirms the Flow is terminal and its cleanup status is pending or failed.
3. The current principal is still unfinished. If the principal is registered, stop; registered
   identities must be preserved.
4. The Flow and the public identifiers match the incident being handled.

Run the existing cleanup operation once with the matching surface model:

```sh
bin/rails runner 'flow = ClientSignUpFlow.find_by!(public_id: "FLOW_PUBLIC_ID"); SignUpArtifactCleanup.call(cycle: flow)'
```

For COM, use `VisitorSignUpFlow` instead of `ClientSignUpFlow`. `SignUpArtifactCleanup.call` locks
and reloads the Flow, checks that it is still terminal, and re-evaluates the principal before
removing pending artifacts. After the call, inspect the Flow's cleanup status and run the report
query again. If cleanup remains failed or any state differs from the diagnosis, do not invoke it
again; escalate to the sign-up owner with the public identifiers and error class.

## `flow_missing` Has No Safe Release Entry Point

There is no Flow to pass to the existing cleanup operation. Do not create or restore a Flow, write
status values directly, or delete the principal/contact manually. Keep the contact held and escalate
to the sign-up owner for a separately reviewed remediation path. The current implementation
deliberately leaves this case unresolved rather than guessing which dependent artifacts are safe to
remove.

## ORG

ORG operator acquisition has no `UNVERIFIED_WITH_SIGN_UP` equivalent, and
`OperatorSignUpFlow` has no cleanup status or attempt counter. The report query therefore rejects
`:org`, and the job does not log an empty ORG result. Do not interpret absence of an ORG report as a
zero count.
