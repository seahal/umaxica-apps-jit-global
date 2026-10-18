# Production Runtime Secret Isolation

Status: backlog. Deferred out of the current cycle by `adr/runtime-secret-isolation-deferred.md`
(2026-10-18). Nothing here is accepted for implementation yet.

## Problem

Every deployed process can read every surface's secrets: one credentials bundle and key per Rails
environment, and one Puma process serving every host. A compromise of any relying party can reach
the OP signing keys and other surfaces' databases. This defeats the purpose of the OP/RP separation
in `one.md`.

## How the current cycle ended (2026-10-18)

R5-WU03A was stopped, not completed and not rolled back. The user judged it beyond what this cycle
could handle and decided on 2026-10-18 to leave every partial result exactly as it is: no rollback,
no correction, no further work. Recovering it is the job of the next cycle.

What exists, untouched:

- Source: `lib/runtime_role.rb`, the per-role credentials path selection in `config/application.rb`,
  `lib/tasks/runtime_roles.rake` (`runtime_roles:provision`) and the `shared`-only development
  pending-migration check (`evidence/2026-10-17-r5-wu03a-runtime-role-boot-R3A1.md`,
  `evidence/2026-10-17-runtime-role-provisioning-R3P7.md`).
- Development state, provisioned on 2026-10-17
  (`evidence/2026-10-17-runtime-role-provisioning-R3P7.md`): per-role encrypted bundles and keys for
  21 non-shared roles in `config/credentials/development/` (keys ignored, bundles untracked),
  per-role PostgreSQL logins with CONNECT limited to their own databases, and read-only Flipper
  grants on `primary`.

What was observed:

- Database separation by login worked: sibling, OP and Zenith connections were refused.
- Secret isolation failed (`TC-R5-03A-001`,
  `evidence/2026-10-17-r5-wu18a-isolated-rehearsal-aggregate-A18R.md`): in the single development
  container every role runs under the same UID, so an RP process could read other roles' key files
  and decrypt the `op-base-app` bundle.
- Process/worker split (03A-P), Solid Queue schema isolation (03A-Q) and ingress/cookie separation
  (03A-I) were never started.

Known inconsistencies left in place on purpose:

- `adr/runtime-secret-isolation-deferred.md` states that per-role bundles and database logins do not
  exist and are not made this cycle; the development state above contradicts it.
- `docs/security/role-secret-isolation.md` and `one.md` R5-WU03A still describe a development-only
  file-permission design.

Effect on `one.md`: WU04, WU05 and WU07 are implemented in source with their Gates open on
`AT-R5-03A`. WU18A, WU19, WU18 and WU20 cannot close under the current `one.md` definitions while
WU03A is stopped. US runtime is separately out of scope for this cycle.

## R5 freeze and closure of this cycle (2026-10-18)

The user closed this cycle's `one.md` implementation on 2026-10-18. R5 is frozen until WU03A is
recovered: no WU18A, WU19, WU18 or WU20 work, no cell activation and no legacy OP-chain removal.
Activating cells without secret isolation would open the new path without the guarantee R5 exists
for. The running application uses the pre-R5 path; R5 cell paths are present but closed (no
`op_client_activations` rows in development on 2026-10-18).

Done after the stop, before closure:

- In-process WU18A sub-cases: two-connection ordering, cached reading caller, JWKS rotation outage
  (`evidence/2026-10-18-r5-wu18a-two-connection-and-jwks-rotation-W18B.md`).
- Real Solid Queue worker stop/kill/restart recovery, and an OP Refresh fix that refuses a Grant
  whose `contract_epoch` is NULL or not current
  (`evidence/2026-10-18-r5-queue-restart-epoch-cutover-and-cross-process-G4X2.md`).
- `two.md` Gate register reconciliation; no Gate is closed
  (`evidence/2026-10-18-two-md-gate-register-reconciliation-G4R1.md`).

Left for the cycle that recovers WU03A:

1. Authorization-code exchange from a root with a NULL or older `contract_epoch` still creates a
   current-epoch Grant. Decide whether the OP refuses it or the 19-COMMON root cutoff alone covers
   it.
2. Gate procedures that do not depend on WU03A (R1-R4; R5 WU02, WU06, WU09-WU16) have partial
   evidence only; run and record them.
3. Cross-process cases (TC-R5-07-003 and others), WU05 receiving capacity and the WU08 time budget
   need a separately reachable OP process and the Jump/Edge path.
4. Then WU04/05/07 Gates, WU18A, WU19, WU18 and WU20 in `one.md` DAG order.

US runtime is out of scope for this programme until another development environment exists.

## Recovery decisions for the next cycle

Decide these before any further WU03A work:

1. Keep, adapt or remove each partial result above. Removing the per-role database logins or bundles
   is a destructive operation and needs explicit approval.
   - Reconsider `config/credentials/development/`. Its 21 per-role `*.yml.enc` bundles were
     committed on 2026-10-18 (`6a208dcb9`) to keep them with the repository; the matching `*.key`
     files are ignored by `/config/credentials/*/*.key` and exist only on the development machine,
     so losing them makes the committed bundles undecryptable. Decide whether the bundles stay in
     git, how their keys are kept or regenerated, and whether this layout survives the chosen
     pod/secret-store mechanism.
2. Correct the ADR, `docs/security/role-secret-isolation.md` and `one.md` R5-WU03A so that they
   describe the observed state and the chosen mechanism.
3. Decide whether WU18A/WU19 keep a hard dependency on WU03A, or whether `one.md` is amended.
4. Then resolve the open decisions below.

## Intended direction (not yet decided in detail)

- Read secrets through `Rails.app.creds`; inject them per pod from a managed secret store (for
  example Google Cloud Secret Manager, with Cloud KMS).
- Split pods as `global`, `publishing` and `regional(n)`; the image stays shared, and only the
  runtime role and the injected secrets differ.
- Give each pod its own PostgreSQL login with grants limited to `RuntimeRole::ROLE_CONNECTIONS`.

## Open decisions for the next cycle

1. **OP signers in the `global` pod.** Choose one, or a combination:
   - a separate OP pod inside `global`;
   - accept OP and worldwide RP co-location in a new ADR, and relax `one.md` R5-WU03A accordingly;
   - KMS asymmetric signing, so that no private key reaches a pod and only the OP service account
     may call sign.
2. **Staging deployment.** Confirm how staging runs (Rails environment, project, secret store) so
   that it gets the same isolation as production.
3. **Queue isolation.** Per-role Solid Queue schemas and grants, or a reviewed alternative.
4. **Boot guard.** Refuse the `shared` runtime role outside development and test.

## Work items once accepted

- Revise `one.md` R5-WU03A and `docs/security/role-secret-isolation.md` to the chosen
  deployed-environment mechanism.
- Define the role-to-pod manifest and per-pod secret list without printing secret values.
- Provision per-pod secrets, service accounts and database logins (needs S/D/E approval).
- Run `AT-R5-03A` against the real restricted pods and record the result in `evidence/`.
