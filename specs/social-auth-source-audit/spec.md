# Social authentication Source audit

Status: verified

## Purpose and scope

The accepted D-101/D-107 contract requires social identity signup, link and unlink facts to commit with a Source audit intent before Chronicle delivery. The prior link and unlink paths wrote `ClientChronicle` directly on a separate database, so a later Source or Ticket failure could leave a false audit event. This change covers app Client social signup, link and unlink. It preserves the existing activity-log presentation and historical Chronicle rows.

## Approved shape

Before: no social Source outbox; `client_chronicles` has no event UUID.

After: `client_social_audit_outboxes(event_uuid UUID unique, operation_ref, owner_ref, identity_ref, provider, provider_subject_digest HMAC-SHA256, event_name [linked|unlinked], occurred_at, released_at, acknowledged_at)` in app Zenith; nullable unique `client_chronicles.event_uuid` in Chronicle. The Source identity's existing `id`, serialized as a string, supplies `operation_ref` and `identity_ref`; there is no identity `public_id`. The Client's `public_id` supplies `owner_ref`. The Source operation supplies the event and time. The subject digest is keyed with the Rails secret and domain separated from other digests; it does not store the raw provider subject. An unlink event records its release time. Chronicle context is derived from the original event facts and retains its existing public shape. There is no positional tuple. `event_name` is one event axis. Existing activity-log API shape and historical Chronicle rows remain unchanged. The migrations are additive and reversible.

The user approved retaining this release proof for app Apple/Google when account termination removes the identity row. This decision does not apply to org Microsoft Entra ID: organizational Microsoft authority is company-owned and must not be automatically unlinked by this app withdrawal path. App withdrawal recovery before termination does not delete the social identity; termination does, and it records the unlink proof in the same Source transaction.

## Acceptance

- AC-1: A committed social signup, link or unlink has exactly one Source audit intent in the same Zenith transaction as its binding transition. A rolled-back transition leaves neither new binding fact nor intent.
- AC-2: A Chronicle or enqueue failure cannot create a false binding outcome or erase the Source intent. A periodic scan delivers missed events and retries without duplicate Chronicle records.
- AC-3: Delivery matches the existing Chronicle activity shape, verifies identity on UUID collision, and fails when seeded event or level references are missing. Request paths do not create reference rows.
- AC-4: Unlink invalidates pending same-actor ceremony evidence without restoring released identity authority after a failure or retry; existing user-visible responses remain stable.
- AC-5: Tests exercise success, Source failure, Chronicle failure and replay across the public use case and delivery job. Migration and schema-drift checks run against isolated databases.
- AC-6: A pre-release app callback or grant cannot authenticate a later owner, reattach, or sign up an Apple or Google subject after unlink or after irreversible account termination removes the identity row. A grant issued after an ordinary unlink may link to another Client. Org Microsoft Entra ID is unchanged.

The broader Phase 23 fault matrix and all other acceptance clauses in `four.md` remain independently required.

Verification for this scoped change: [2026-10-09 social release and Source audit acceptance](../../evidence/2026-10-09-social-release-acceptance-Q4P7.md). This status does not assert a whole-contract ACCEPTED verdict.
