# Rails Jump contract freeze

The accepted plan is `plans/active/rails-jump-directed-handoff-rollout.md`; the decision is
`adr/jump-directed-rails-handoff-contract.md`.

The 2026-10-02 instruction supersedes the earlier development blanket gate, Edit issuer retention
and production `jpx.*` Host Authorization retention. Persistence defaults and rows are untouched.
Palm was already implemented and approved; this change characterizes its existing ceremony and
updates conflicting current documentation rather than replacing the RP.

Development public identities are explicit environment authorities for existing logical nodes,
not new graph nodes. Their return-origin binding is checked before activation. Production public
JWK snapshots are required because a development-prefixed kid alone cannot prove key separation.
Snapshot completeness and public JWKS reachability remain deployment responsibilities; Hono trust
registration is not asserted by Rails. Dedicated development key settings have no auto-generated
or production-key fallback. Local-only development remains available with Jump issuance disabled
for unconfigured surfaces.

Existing staged preference API work and unrelated worktree changes are retained. No formatter or
auto-fix is run. Final verification results are recorded separately in `evidence/`.
