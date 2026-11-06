# WU-A2 App registration completion receipt shape

**Status: Approved for implementation and local migration by the owner on 2026-11-02.**

The owner explicitly approved the proposed shape and local migration in the conversation, assigning
issue 1 to Codex. This does not authorize production/Neon operations, historical backfill or
deletion of completion facts. Implementation and verification are tracked in
`specs/app-registration-completion-receipt/spec.md`.

## Contract

`two.md` §12.4 requires registration completion to be an immutable fact independent of the current
Client status and the OP sign-up Flow. The receipt belongs to the source principal database. Its OP
Flow reference is opaque because the Flow is stored in another database. The existing accepted
sign-up finalization ADR makes App Email, Telephone, Google, and Apple real completion paths.

The inspected ORG invitation controller always refuses with the Bureau migration message, and
`OrgOperatorLifecycleInvitationAcceptance` also returns failure. There is no active Operator
registration finalizer to receive a receipt. This proposal therefore covers App only; it does not
create an empty ORG receipt table or enable invitation registration.

## Before

No registration completion receipt table or record exists. Source completion currently changes the
Client/contact/social identity and audit records. The OP `ClientSignUpFlow` later moves through its
own completion states, which are not an authoritative source-completion record.

Read-only local inventory with `.env.container.devcontainer` loaded:

| Environment | Client rows by status ID | ClientSignUpFlow rows | `client_registration_completions` table |
| ----------- | -----------------------: | --------------------: | --------------------------------------- |
| Development |                        0 |                     0 | absent                                  |
| Test        |     7 (`11`: 6, `13`: 1) |                     0 | absent                                  |

These counts do not establish old registration completion and will not be used to backfill receipts.

## Proposed after shape

App Zenith only:

| Table                                    | Column             | Type / constraint                                        | Authoritative source                                                      |
| ---------------------------------------- | ------------------ | -------------------------------------------------------- | ------------------------------------------------------------------------- |
| `client_registration_completion_methods` | `id`               | `smallint` primary key, NOT NULL                         | fixed migration-seeded reference                                          |
|                                          | `key`              | `varchar(16)`, UNIQUE, NOT NULL                          | fixed values: `email`, `telephone`, `google`, `apple`                     |
| `client_registration_completions`        | `id`               | `bigint` primary key, NOT NULL                           | database                                                                  |
|                                          | `public_id`        | `varchar(21)`, UNIQUE, NOT NULL, length CHECK 21         | `PublicId.generate`                                                       |
|                                          | `client_id`        | `bigint`, UNIQUE, NOT NULL, FK to `clients.id`, RESTRICT | locked Client whose new registration is being completed                   |
|                                          | `sign_up_flow_ref` | `varchar(21)`, UNIQUE, NOT NULL; no cross-database FK    | current, ownership-checked `ClientSignUpFlow.public_id`                   |
|                                          | `method_id`        | `smallint`, NOT NULL, FK to the method reference         | current Flow's `entry_method`, checked against verified completion source |
|                                          | `completed_at`     | `timestamptz`, NOT NULL                                  | App Zenith database clock at the source commit                            |

Conceptual row:

```text
{ public_id, client_id, sign_up_flow_ref, method_id, completed_at }
```

There is no `status`, nullable field, `created_at`/`updated_at`, Client status snapshot, or OP FK.
The method dimension is independent of actor, Flow, and time. The method is derived from the locked
Flow and its verified source, never from request parameters.

## Writer and transaction consequences

Create the receipt in the same App Zenith transaction that commits the new source registration:

- Email: the actor/contact transaction in `SignUpSequenceControllerSupport`.
- Telephone: `SignAppUpTelephoneRegistrationFinalizer`.
- Google/Apple: `SocialAuthSignupFinalizer`.

The source writers must verify the Flow, actor, contact/provider evidence and registration
transition before inserting. An existing exact receipt makes reconciliation idempotent; a previously
registered Client without a receipt is not retroactively classified by its status.

The §12.4 Cancel boundary also requires changing the present OP-Flow-lock-then-source-write path.
The accepted two-stage order is OP authorization consumption, followed by an OP read transaction
without row locks around a source transaction that locks the actor and then the relevant OP
parent/Flow. The parent lock stays held until the source commit result is known. A committed receipt
must be checked before Flow cleanup, automatic expiry, Secret completion or termination; it protects
a real registration if the OP update was interrupted after source commit.

## Migration, compatibility and verification

The migration is additive to `db/app_zenith_migrate`, seeds the four fixed method rows, and does not
backfill existing Clients or Flows. Development and Test currently have no receipt table. No
production, Neon or external database operation is proposed. The migration's down behavior must not
silently discard receipt rows; a local down/up rehearsal is limited to an empty receipt table.

Focused tests after approval must cover each of the four source writers; exact Flow/actor/method
ownership; rollback when receipt creation fails; duplicate finalization; Parent Cancel before and
after the source commit; completed registration protected from Secret lifecycle/cleanup; and the
absence of inferred receipts for existing verified Clients. `two.md` §12.4's broader lock-order
cases remain acceptance work, not a claim from this proposal.
