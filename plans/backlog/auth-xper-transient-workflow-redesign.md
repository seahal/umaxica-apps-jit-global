# Future Auth / Xper Transient Workflow Redesign

Status: backlog. Explicitly out of scope for the current Base/RP consolidation cycle, per
`adr/defer-auth-xper-transient-workflow-redesign.md`.

## Goal

Revisit Auth and Xper after the current RP/Base work and decide whether both should use a common
transient-capability substrate while retaining separate domain workflows.

The discussion behind this plan is in
`memos/2026-10-05-claude-auth-xper-transient-workflow-future-design.md`.

## Required future work

1. Audit Auth's current admission and result, ceremony-session, sign-out, JWKS and Jump-related, and
   residual Sign- and Acme-era paths. Classify each as ceremony responsibility, Base authority
   responsibility, compatibility-only behavior, or removable legacy behavior.
2. Define Xper's Experience authority and persistence boundary before committing to a mandatory
   result-return path.
3. Decide the transient-capability primitive: raw-token generation, digest-domain separation,
   namespace, purpose, consumer, and Browser Session binding, TTL, atomic consume and supersede
   behavior, and fail-closed semantics.
4. Evaluate a Browser-Session-scoped current-workflow slot with at most one active Auth workflow and
   one active Xper workflow. Evaluate latest-generation-wins semantics rather than retaining durable
   consumed-token history.
5. Re-evaluate the candidate absolute workflow lifetimes, approximately 5 minutes for Auth and 30
   minutes for Xper, separately from the much shorter admission and result capability TTLs.
6. Preserve the rule that capability values do not travel in URL query strings or fragments. Audit
   browser handoff transport independently for Auth and Xper.
7. Keep Auth and Xper domain code separate even if they share a low-level capability primitive.
8. When implementation begins, add public and integration behavior tests, replay and supersession
   tests, fail-closed store-failure tests, and equivalence-partition and boundary-value coverage.
9. Record the final design in a new or amended ADR before implementation.

## Current-cycle prohibition

Do not modify Auth or Xper implementation as part of the current Base/RP refactor solely to advance
this plan. Do not opportunistically merge their concerns into the shared RP layer.
