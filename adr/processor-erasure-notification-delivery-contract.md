# Processor Erasure Notification Delivery Contract

Status: Accepted (2026-09-23)

## Context

Privacy erasure notifications are created for the `app` and `com` processor boundary and are dispatched
asynchronously through Solid Queue. A queue enqueue or a processor request is not proof that the processor
accepted or completed the notification. The previous state model did not provide a provider-neutral
receipt boundary, a persisted attempt identity, bounded retry exhaustion, or an immutable terminal
failure state.

No concrete external processor adapter or provider protocol is approved by this decision. The repository
therefore remains fail-closed until an adapter is registered.

## Decision

Each notification owns a monotonic `delivery_generation` and one digest-only request idempotency identity
for that generation. Every retry in the same generation reuses that identity; authorized manual recovery
advances the generation and creates a new identity. Each dispatch attempt is persisted with its
generation, attempt number, processor key, the generation's idempotency identity, outcome, timing, and
error metadata. The database enforces positive generation and attempt values, unique attempt numbering,
and indexed idempotency lookup within a notification generation. Attempt rows have no independent retention
window: they inherit the parent notification's purge eligibility, so their foreign key deliberately
uses `ON DELETE CASCADE` for the existing set-based retention purge.

The notification state machine is:

```text
PENDING -> RETRYABLE_FAILURE -> PENDING
PENDING -> NOTIFIED
PENDING -> PERMANENT_FAILURE
PENDING -> SKIPPED
PERMANENT_FAILURE --authorized recovery--> new PENDING generation
```

`NOTIFIED` is reachable only from a `ProcessorErasureVerifiedReceipt` produced by a registered adapter.
The receipt must be bound to the notification public identifier, processor key, current generation, and
generation idempotency digest. The state update and attempt success update are serialized under the
notification row lock. Duplicate delivery of the same verified receipt is idempotent; forged, stale,
cross-notification, cross-processor, cross-generation, and different-receipt callbacks are rejected.

An adapter exposes a finite retry policy and returns one of: verified receipt, accepted-but-pending,
retryable failure, or permanent failure. Accepted-but-pending attempts expire under a bounded lease and
are then classified by the retry policy. Retry exhaustion is an immutable `PERMANENT_FAILURE`; workers do
not retry that generation. Manual recovery is a separate authorized operation that increments the
generation and preserves all prior attempt rows.

The empty adapter registry is intentional. Missing configuration is a terminal local failure, not a
successful notification. Provider authentication, provider credentials, provider receipt protocol,
provider-specific retry values, and provider end-to-end verification are deployment/provider gates and
are not inferred by this ADR.

Occurrence records describe requested, notified, failed, and manual-recovery events only. They are audit
history, not the notification state authority. No raw receipt, credential, token, or provider secret is
stored in the notification or attempt records.

The cascade applies only after the parent notification is selected by the existing explicit retention
allowlist and purge guards. It does not bypass retention holds or enforcement blocks on the parent and
is not a delivery-state transition.

## Alternatives rejected

- Treating enqueue or an unverified response as `NOTIFIED` would create false-success evidence.
- Storing raw provider receipts or credentials would turn a low-level delivery record into a secret store.
- Retrying terminal failures automatically would make permanent failure non-terminal and could cause
  uncontrolled repeated requests.
- Adding a generic provider framework or a live provider integration without an approved processor
  contract would invent an external authority.

## Consequences

The repository can verify the state, idempotency, receipt binding, retry, exhaustion, and recovery
contracts with an approved fake adapter without contacting an external provider. A real provider remains
unavailable until its adapter authentication and receipt contract are separately approved and configured.
The provider deployment gate must demonstrate authenticated receipt, retry, retry exhaustion, permanent
failure, and manual recovery behavior using the real processor.
