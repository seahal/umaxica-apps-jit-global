# Sign-Up Physical Purge Worker

## Status

Backlog. The current expiry sweep is not this physical-purge worker and does not change this scope.

## Problem

`SignUpTermination` and `SignUpArtifactCleanup` schedule logical deletion by writing `discarded_at`,
`purged_at`, deleted status ids, and cleanup state. They do not physically delete rows whose
`purged_at <= now`.

Without a dedicated purge worker, cancelled sign-up artifacts can remain in the database
indefinitely and continue to carry personal data after the intended retention window.

## Scope

Create a Solid Queue worker that physically purges sign-up artifacts only after the retention
boundary has elapsed.

The worker must cover:

- `client_sign_up_cycles` and `visitor_sign_up_cycles`.
- Pending sign-up contacts: client/visitor emails and telephones.
- Pending telephone sign-up passkeys.
- Pending app social identities created only for sign-up.
- Any future sign-up artifact that opts into the same retention contract.

## Requirements

- Purge only records with `purged_at <= now` and a deleted or terminal cleanup status.
- Preserve audit history in Chronicle or another audit store before purge.
- Use small batches with `FOR UPDATE SKIP LOCKED`.
- Use per-record or per-aggregate retry with bounded backoff.
- Emit metrics for scanned, purged, skipped, failed, and retry-exhausted records.
- Never query dependent artifacts broadly by email, telephone, or social uid alone; use cycle-owned
  artifact pointers and actor ids.
- Do not rely on token `ON DELETE CASCADE` to remove cycles.
- Document operational recovery for purge failures and schema drift.

## Open Decisions

- Whether purge should be owned by a generic `RetentionPurgeJob` or a sign-up-specific worker.
- Whether terminal states need different purge delays (`CANCELLED`, `EXPIRED`, `FAILED`).
- Whether dependent rows should be hard-deleted directly or moved to a redacted tombstone first.
- Whether `cleanup_status` should become a reference table before purge automation ships.
