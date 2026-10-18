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

## Current implementation checkpoint (2026-10-14)

The current inspected HEAD is `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`; the worktree is
extensively dirty (855 changed or untracked entries at the latest focused run). The user directed
this delivery to use only the ordinary Rails `development` and `test` databases. No isolated fleet,
reset, migration rehearsal, or manual cleanup was used for the current follow-up.

- **AV-5 / REQ-071 — HTTP authority: PASS.** APP and ORG controller cases cover member/login
  refusal, cross-surface and wrong-organization refusal, destination-only cancel refusal, alternate
  Avatar input, and authorized cancel by a different source owner. See
  [`C8M2`](../../evidence/2026-10-13-avatar-step17-http-authority-followup-C8M2.md).
- **AV-3 / AV-6 — independent connection races: BLOCKED.** The committed tests stop at the existing
  run-owned worker receipt guard because worker receipts are unavailable. The guard was not
  bypassed. The post-correction full Rails run recorded 14 errors from that same gate across
  `AvatarOwnershipTransfersConcurrencyTest` (6), `AvatarConcreteOwnershipPeriodTest` (5),
  `AvatarMonikerWriterConcurrencyTest` (1), `AvatarRetentionPurgeTest` (1), and
  `AvatarTransferReservationTest` (1); it recorded no functional failures. The committed-history
  tests intentionally retain synthetic Avatar/history rows for the owning worker database to be
  discarded, so running them unchanged against the shared test database would leave persistent test
  history. The latest standard-database rerun after a Passkey test fixture correction recorded the
  same 14 receipt errors, 15,256 runs, 128,994 assertions, 0 failures and 0 skips, with no Strict
  Loading errors. See [`S4N8`](../../evidence/2026-10-13-avatar-standard-test-boundaries-S4N8.md),
  the [post-correction suite record](../../evidence/2026-10-14-step20-post-fix-suite-C7P2.md), and
  the [latest rerun](../../evidence/2026-10-14-passkey-slot-standard-test-followup-C9R2.md).
- **MIG-2 / MIG-4 — rebuild, restore and cutover rehearsal: BLOCKED.** These acceptance conditions
  remain unverified; no database reset or cutover was performed.
- Four synthetic Groups created by an earlier test run remain in `test_avatar_db`; no deletion was
  performed. The transaction isolation repair stopped further Group-count growth. See
  [`S4N8`](../../evidence/2026-10-13-avatar-standard-test-boundaries-S4N8.md).

- **AV-5 replay over HTTP (2026-10-15):** reused-key different-input and different-initiator
  refusals (APP) and keyless-after-cutover refusal (APP and ORG) were added and pass; see
  [`M2T6`](../../evidence/2026-10-15-step17-step18-followups-M2T6.md).

This checkpoint supersedes the older “latest inspected code HEAD” above for current resumption. The
backlog remains open; no incomplete condition is promoted to PASS.

### Ownership consumer ledger follow-up (2026-10-14)

The AV-1 / AV-8 / AV-7 source census is now recorded in
[`A7Q4`](../../evidence/2026-10-14-avatar-ownership-consumer-ledger-A7Q4.md). It traces the current
Avatar and Group ownership source through bootstrap, selector/switcher, APP/ORG Avatar surfaces,
policies, Group management and memberships, transfer flows, Grants, transition tools and retention
maintenance. Added rollback-scoped post-marker regressions for Avatar provisioning, Switcher
candidate resolution, Avatar/Group policies, Group create/update/archive and Group membership
attach/reorder/detach. APP and ORG Avatar controller tests now exercise post-marker moniker updates
over their authenticated HTTP routes and assert the matching concrete owner with no new legacy
ownership row. The existing APP groups controller test also exercises post-marker membership HTTP
create/reorder/detach and confirms concrete owners with account context intact. Added Grant
assertions for non-owner recipient re-issuance and the complete `avatar.grant.manage` /
`avatar.transfer.*` refusal set. The combined focused selection passed 248 runs / 1,336 assertions;
RuboCop passed 15 changed Ruby test files. A post-marker registry-accept test also confirms that
transfer keeps a destination-owned Group membership, removes a former-owner mismatch and preserves
both Groups' selected account contexts.

This is local source and simulated-marker evidence. It does not establish persistent operational
cutover for every consumer. AV-3 / AV-6 committed-history races and MIG-2 / MIG-4 persistent
transition rehearsal remain blocked by the shared-test-database constraint; their guards and
acceptance criteria remain unchanged.

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
