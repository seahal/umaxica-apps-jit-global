# Repository knowledge and shared agent harness

Accepted: 2026-10-09

## Decision

Adopt the responsibilities in [repository knowledge architecture](../docs/reference/repository-knowledge-architecture.md)
and the [spec lifecycle](../specs/README.md). The user approved implementation after accepting the
rejected alternatives and excluding external environments and temporary root auth documents.

Use one canonical `.agents/` layer, a shared root router, and vendor-specific discovery adapters.
Keep concise Skills only where an explicit procedure adds value beyond ordinary model capability.
Use structural scripts and CI for deterministic checks; instructions cannot enforce sandboxing.

## Consequences

Closed specs retain historical change meaning while docs describe the current system. Research is
non-normative and has no general maintenance obligation. Risk and checklist records are proportional
to actual needs. Local acceptance IDs suffice; traceability becomes stronger for high-risk changes.
Vendor documentation and installed-runtime observations remain separate claims.

## Rejected alternatives

- A top-level governance, risks or controls hierarchy: too broad an ownership sink.
- Reusing `spec/` for prose: conflicts with the Vitest migration; use `specs/` and `gait/`.
- Duplicated vendor instruction or Skill bodies: creates independent drifting authorities.
- Importing every rule or treating `.mdc` as native runtime enforcement: context bloat and false gates.
- Mandatory specs, phase approvals, global IDs or multi-agent reviews for every edit: disproportionate.
- Maintaining closed specs as current truth or letting code automatically override contracts:
  obscures change history or turns defects into policy.
- Archiving every root document or repairing every stale research note: loses accepted contracts
  and imposes maintenance on deliberately non-authoritative history.
- Rewriting old evidence to current names, or treating async auto-fix hooks as verification:
  misrepresents observations.
- Adopting Spec Kit or OpenSpec wholesale: useful workflow ideas do not justify a second current
  source of truth, generated scaffolding or a new framework dependency.
- Encoding model-generation quirks as permanent constraints: runtime compatibility is reviewed
  against current documentation and local checks instead.

Temporary `one.md` through `five.md` and their references are deliberately retained at the user's
request. Their removal is a separate ownership decision, not a prerequisite for this architecture.
