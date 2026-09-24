# Withdrawal and Privacy Erasure Boundary

This document describes the implemented `app` and `com` withdrawal boundary for `Client` and
`Visitor` subjects. It does not define `org` operator withdrawal, workspace closure, billing
closure, or legal workflow policy.

## Authentication Boundary

Normal authentication is only for active `Client` and `Visitor` subjects. The current-resource
resolver rejects deactivated, suspended, withdrawn, or terminated subjects before they become
`current_client` or `current_visitor`.

HTML requests from such subjects are sent to the withdrawal session entry route for the matching
surface. JSON and API requests receive `403` with `WITHDRAWAL_REQUIRED`. Refresh-token and edge
flows must continue to treat deactivated subjects as ineligible for normal authentication.

Withdrawal ceremony sessions are separate from normal authentication. They do not issue normal
access tokens, refresh tokens, DBSC state, or device-binding state. They use the dedicated
withdrawal ceremony cookie and resolve the subject as `current_withdrawal_subject`, not as a normal
current resource.

## Ceremony Re-entry

The `app` and `com` surfaces expose withdrawal session entry routes for suspended subjects that have
lost the ceremony cookie. Re-entry uses the existing email OTP channel for verification before
issuing a new ceremony cookie.

The entry response is intentionally generic for unknown, active, and otherwise ineligible subjects.
Entering an email address alone is not enough to issue a ceremony. Active subjects do not receive a
withdrawal ceremony.

## Privacy Erasure Requests

Privacy erasure requests are separate from normal withdrawal. They are stored in subject-local
tables for `Client` and `Visitor` subjects and track request kind, jurisdiction, request source,
status, response due date, denial reason, retention exception, legal-hold blocking, and final
response timestamps.

Self-service erasure requests are created through a valid withdrawal ceremony. A received request is
cancelled when the subject recovers. Verified, processing, completed, partially denied, failed, or
legal-hold-blocked requests block normal self-service recovery.

## Retention Holds

Retention holds are stored separately for `Client` and `Visitor` subjects. Active holds block
purge/shred processing. Released and expired holds do not block purge.

When a hold blocks purge for a subject with an open privacy request, the request is marked
`blocked_by_legal_hold`. Subject lifecycle state remains the source of truth for recoverability and
finalization; hold rows do not replace that lifecycle state.

## Occurrence Records

Withdrawal, ceremony, privacy erasure, purge/shred, hold-skip, and processor-notification events are
recorded through the occurrence infrastructure. Occurrence rows are history and evidence only. They
must not become the current-state source of truth for lifecycle, privacy request, retention hold, or
processor notification status.

Occurrence context must not include plaintext tokens, plaintext email, plaintext phone numbers, or
raw IP addresses. User agents are stored as digests when included.

## Processor Notifications

Privacy erasure requests create processor notification rows and enqueue Solid Queue jobs. The job is
idempotent: terminal notifications are left unchanged, an implemented processor may move its row to
`NOTIFIED` only after its adapter has authenticated and normalized a receipt bound to the notification,
processor, delivery generation, and generation-scoped idempotency digest. Retries in one delivery
generation reuse that idempotency identity; authorized recovery creates a new generation and identity.
A dispatch acknowledgement without a verified receipt remains pending and cannot produce a success
occurrence. Attempts persist their generation, bounded attempt number, processor, the generation's
digest-only idempotency identity, outcome, and error metadata; raw provider credentials and receipt
secrets are not persisted.

Retryable failures are bounded by the processor adapter's finite retry policy. Exhaustion produces the
immutable `PERMANENT_FAILURE` terminal state. An authorized operator may open a new delivery generation
through the recovery operation; prior attempts and their terminal outcome remain immutable, and the
worker never retries a permanent generation. The repository provides the provider-neutral adapter,
receipt, retry, and recovery contracts, while the adapter registry remains intentionally empty until
an independently approved processor integration supplies authenticated dispatch and receipt behavior.
Unsupported processors therefore remain explicit failure/manual-follow-up states.

Processor integrations that are not implemented remain explicit failure or manual follow-up states
instead of silently succeeding.
