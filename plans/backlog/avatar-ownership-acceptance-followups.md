# Avatar ownership acceptance follow-ups

Status: backlog

## Context and scope

On 2026-10-13, the user accepted the current Avatar implementation for this `nine.md` delivery and
requested that the remaining investigation be retained in the backlog. This is an explicit delivery
exception, not evidence that the unverified behavior passes or that production cutover is ready.
Future implementation must be scoped after investigation.

The latest inspected code HEAD was `4828aeedd141b54163236672890799b9b01128c2`, with uncommitted
tests and documentation. See
[the final assessment](../../evidence/2026-10-13-nine-final-acceptance-R8D4.md) and
[the isolated rehearsal results](../../evidence/2026-10-13-nine-acceptance-follow-up-F7K2.md).
Revalidate the checkout and existing tests when this work resumes.

## Investigation backlog

| Boundary                           | Question to resolve                                                                                                                                                                                           | Existing starting points                                                                                                         |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| AV-1, AV-8: writers and consumers  | Do all actual provisioning, retained-data and Group readers/writers use the intended concrete authority after cutover while preserving independent account context?                                           | `AvatarProvisioning::Create`, Group backfill/cutover operations, Group membership tests and the synthetic real-COMMIT rehearsal. |
| AV-3, AV-6: concurrent transitions | Are actor authority, source generation and destination acceptance revalidated after lock waits? Do competing transfers and serialization/deadlock failures preserve a single uninterrupted ownership history? | Concrete-period RC/RR/Serializable tests, registry concurrency tests, and four-direction destination-write failure tests.        |
| AV-5: HTTP authority               | Do request/accept/cancel operations enforce the correct actor, selected Avatar, source/destination authority and operation-specific Step-Up scope across actual APP/ORG paths?                                | APP/ORG transfer controller tests and registry request/replay tests.                                                             |
| AV-7: Grants                       | Do all supported Persona/Agent, capability, expiry, revocation and generation combinations deny stale or unrelated authority while allowing intended N:M access?                                              | `avatar_access_grants_test.rb`, permission resolver tests and O1-to-O2-to-O1 regression.                                         |
| MIG-2, MIG-4: Avatar transition    | Are draft provenance, reverse-object lifecycle and local reader/writer reconciliation fully accounted for beyond the successful synthetic migration/restore/cutover rehearsal?                                | Avatar ownership spec, migration inventory, cutover/barrier tests and F7K2 evidence.                                             |

These are investigation gaps, not confirmed defects. Preserve the passing temporal integrity,
registry, rollback/retry, history and retention-deferral tests. Add only missing public-boundary
cases after reading their existing bodies. Use owned disposable databases for committed races and
migration rehearsals; do not disable integrity protections or alter shared data.

## Completion conditions for a future follow-up

- Map each question to actual supported code paths and existing behavioral assertions.
- Record each outcome as verified behavior, reproduced defect or a precisely bounded remaining gap.
- For reproduced defects, add a meaningful regression and implement a scoped correction with
  appropriate authority; preserve public identities and ownership history.
- Record revision, dirty scope, commands and results. A passing suite count alone does not close an
  untested authority or concurrency boundary.

Production cutover and unresolved privacy policy remain separately deferred. Authentication
binding/authorization verification, the ORG halt audit defect, and permanent public-ID protection
remain in the current delivery scope; this backlog does not defer them.

Canonical contracts: [Avatar checklist](../../docs/checklists/avatar-ownership.md) and
[delivery acceptance](../../specs/integrated-stack-delivery/acceptance.md#scoped-avatar-acceptance--2026-10-13).
