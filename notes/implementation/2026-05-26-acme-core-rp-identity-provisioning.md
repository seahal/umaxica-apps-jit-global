# Acme/Core RP Identity Provisioning Implementation Notes

## Context

- Original request: Defer Acme/Core bridge model naming refactor to `plans/`, then repair Core RP
  provisioning and share the RP callback concern across Acme and Core.
- Related docs/plans: `docs/architecture/database-boundaries.md`, `adr/acme-rp-boundary-naming.md`.
- Implementation date: 2026-05-26.

## Decisions Made During Implementation

- Decision: Add `Oidc::RpIdentityProvisioning` for Acme/Core callback controllers.
  - Why: The previous callbacks resolved `payload["sub"]` directly against the actor table in each
    controller. The shared concern now prefers stored `*Identity` mappings and keeps the fallback
    path centralized.
  - Alternatives considered: Rename the bridge models immediately; deferred because the user asked
    to plan that cleanup for later.
  - Follow-up needed: Decide whether `*Identity.source_record_id` should remain unique or become
    unique per RP audience.

- Decision: Keep current `Core*Bridge` model names for now and create missing Core bridge rows from
  the shared provisioning path.
  - Why: Core RP needs a local projection today, while model/table naming is a separate migration
    matrix.
  - Alternatives considered: Introduce Acme bridge models now; deferred until the naming plan is
    accepted.
  - Follow-up needed: Execute the backlog naming plan before any broad model/table rename.

## Deviations From Plan

- Change: No schema migration was added.
  - Why: The existing `source_record_id` uniqueness constraint makes multi-RP identity rows a
    broader compatibility decision.
  - Risk: If both Acme and Core need separate persisted claim rows for the same actor, the schema
    must change before that can be represented.
  - Follow-up: Tracked in the backlog plan.

## Review Notes

- Tests run:
  - `bin/rails test test/controllers/concerns/oidc/callback_test.rb test/controllers/concerns/oidc/rp_identity_provisioning_test.rb test/integration/core_rp_browser_flow_test.rb test/models/core_rp_bridge_test.rb`
- Tests not run:
  - Full suite.
- Documentation or ADR promotion needed:
  - Promote the final bridge naming decision to ADR if the deferred refactor is accepted.
