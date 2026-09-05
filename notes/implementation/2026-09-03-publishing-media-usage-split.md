# Publishing Media Usage Split Implementation Notes

## Context

- Original plan/spec: Phase 1B publishing architecture remediation.
- Related: `adr/publishing-persistence-polymorphism-prohibition.md`,
  `docs/architecture/publishing-persistence.md`.
- Implementation date: 2026-09-03

## Decisions Made During Implementation

- Decision: two tables `publishing_revision_media_usages` and
  `publishing_version_media_usages`, following taxonomy assignment naming.
  - Why: explicit ownership matching the locked design.
  - Alternatives considered: keep one table with a non-null type discriminator.
    Rejected — still persistence polymorphism.
  - Follow-up needed: none.

- Decision: copy media on promote and restore, and add a deferred completeness
  trigger analogous to taxonomy.
  - Why: promotion previously ignored media; that would leave released versions
    without placements after the split.
  - Follow-up needed: none.

- Decision: keep `PublishingContentRendering` as one concern.
  - Why: list/detail/query/serialize/cache/error is one public-content HTTP
    contract. Splitting would hide a single flow.
  - Follow-up needed: none.

- Decision: do not split `restored_from_revision_id` / `restored_from_version_id`
  on revisions.
  - Why: optional restore provenance, not owner-or-owner of the row. Out of
    this phase's media-usage scope.
  - Follow-up needed: architecture owner if provenance should also be explicit.

## Review Notes

- Tests run: see `evidence/2026-09-03-publishing-phase-1b-finalization.md`.
- Follow-up: Phase 1B finalization removed the transitional migrations and
  duplicated `entry_id`/`locale` columns. Fresh migrate creates the final
  tables directly.
- Documentation promotion: `docs/architecture/publishing-persistence.md` and
  the polymorphism-prohibition ADR were updated for pre-deployment history.
