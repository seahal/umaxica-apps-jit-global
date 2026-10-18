# Runtime Secret Isolation Is Deferred Beyond the Current Cycle

## Status

Accepted (2026-10-18). User decision in conversation on the same day. This is a scope decision: the
problem is acknowledged and will be solved in a later cycle; this cycle implements no further part
of it. It changes no code, credential, database login or deployment.

Follow-up plan: `plans/backlog/2026-10-18-production-runtime-secret-isolation.md`.

## Context

`one.md` R5-WU03A requires that a relying-party process can neither read nor decrypt an OP signing
key, another cell's private key or another surface's database login. Observed on 2026-10-18 at HEAD
`17903f7d121aa33efe29f2db9235c9aa5db4b001` (uncommitted worktree):

- Development and production each use one encrypted credentials bundle and one key
  (`config/credentials/<env>.yml.enc` and `<env>.key`) for every surface.
- The production image (`Containerfile`, `production` stage) runs one Puma process that serves every
  host, so every surface's code runs with every surface's secrets.
- Staging has no Rails environment of its own; how staging is deployed was not verified from the
  repository.
- `lib/runtime_role.rb` and the per-role credentials path selection in `config/application.rb` exist
  as a first step (`evidence/2026-10-17-r5-wu03a-runtime-role-boot-R3A1.md`). Per-role bundles,
  per-role database logins and queue isolation do not.

Public verification keys published through `.well-known` are not part of the problem; `one.md`
allows them to be shared. The exposure is private signing keys, the shared master key and broad
database credentials.

The intended production direction is known in outline but not decided in detail:

- secrets read through `Rails.app.creds`, injected per pod from a managed secret store (for example
  Google Cloud Secret Manager, with Cloud KMS) so that each pod can see only its own secrets;
- pods split as `global`, `publishing` and `regional(n)`.

That split leaves an open question. A `global` pod would hold the realm OP signers together with the
worldwide RPs (`rp-base-*-ww`, `rp-edit-org-ww`, `rp-tech-org-ww`), so a compromise of one of those
RPs could still reach an OP signing key. Candidate answers (a separate OP pod, accepting the
co-location in a new ADR, or KMS-held signing keys with signing permission granted only to the OP
service account) cannot be chosen yet.

## Decision

1. **Not implemented in this cycle.** No per-role credentials bundle, key, database login, queue
   schema, process split or deployment change is made for R5-WU03A in this cycle.
2. **Development accepts the shared role.** The development container stays unsplit, as the user
   decided on 2026-10-17. It runs as the `shared` runtime role; its secrets are disposable, and this
   exposure is accepted for development only.
3. **Production and staging remain an open defect, not an accepted risk.** Running every surface
   with one shared secret set is not an acceptable final state for any deployed environment. This
   ADR records that the defect is known and deferred. It does not accept it.
4. **The isolation boundary for deployed environments will be the pod and its secret-store access
   policy**, not file permissions inside one process. The exact pod split, the placement of OP
   signers and the use of KMS signing are decided in the follow-up cycle.
5. **`AT-R5-03A` stays open.** It is NOT_RUN for this cycle and keeps R5 activation closed. No later
   gate may count it as passed because of this deferral.

## Consequences

- R5 work that depends on R5-WU03A (`one.md` dependency table: WU04, WU05, WU07, WU18A, WU19) may
  proceed in source, but its activation gates stay closed until WU03A is accepted.
- The existing `RuntimeRole` code stays in place as the transitional mechanism. Its exit condition
  is unchanged: a cell process must boot with its own role and never as `shared` once the cell is
  activated.
- When the follow-up cycle starts, `one.md` R5-WU03A and `docs/security/role-secret-isolation.md`
  are revised to the deployed-environment mechanism chosen then; they currently describe a
  development-only file-permission design.
