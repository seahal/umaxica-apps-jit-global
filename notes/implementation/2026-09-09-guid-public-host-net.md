# GUID Public Host Override Implementation Notes

## Context

- Original plan/spec: `adr/guid-identifier-surface.md` (2026-09-08) named `guid.umaxica.id`.
- Related decisions/docs/plans: `docs/architecture/guid-surface.md`, Host Authorization, GUID routes.
- Implementation date: 2026-09-09.

## Decisions Made During Implementation

- Decision: override the public GUID host to `guid.umaxica.net`; retire `guid.umaxica.id` with no
  compatibility period; keep `guid.net.localhost:3000` as the development ingress.
  - Why: the tunnel presents `Host: guid.umaxica.net`. The previous ADR's `.id` name was rejected by
    Host Authorization. Explicit user instruction overrides the prior ADR.
  - Alternatives considered: admit both `.id` and `.net`. Rejected: two public names for an unshipped
    surface, and the prior ADR already used a clean cut for `eid.*`.
  - Follow-up needed: production and Cloudflare must publish `guid.umaxica.net` (not `.id`) as
    `PUBLIC_GUID_SERVICE_URL`.

## Deviations From Plan

- Change: rewrite `adr/guid-identifier-surface.md` in place with a superseding status, rather than a
  second ADR file.
  - Why: this repository names ADRs by topic, not sequential numbers; Core used the same in-file
    supersession pattern.
  - Risk: readers of the 2026-09-08 revision in git history may still quote `.id`.
  - Follow-up: none in-repo.

## Review Notes

- Tests run: after the host-side rename of the frontend alias in `.devcontainer/compose.yaml` to
  `guid.umaxica.net`, `bin/rails test` on Host Authorization, GUID surface, and GUID routes:
  14 runs, 143 assertions, 0 failures.
- Tests not run: full `bin/rails test` suite.
- Documentation promotion needed: none; ADR and `docs/architecture/guid-surface.md` are updated.
