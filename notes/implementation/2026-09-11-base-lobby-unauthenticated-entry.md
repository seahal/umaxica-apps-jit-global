# Base Lobby Unauthenticated Entry Implementation Notes

## Context

- Original plan/spec: current conversation, Base `/lobby` as the canonical unauthenticated entry
  and PRG sign-out completion
- Related decisions/docs/plans: `adr/base-lobby-unauthenticated-entry.md`,
  `adr/logout-ceremony-boundary.md`, `docs/security/logout-sequence.md`
- Implementation date: 2026-09-11

## Decisions Made During Implementation

- Decision: use existing `SignOutNotice` rather than Rails `flash[:notice]`
  - Why: repository policy forbids Rails flash; `SignOutNotice` is already the one-time,
    session-bound sign-out marker and is consumed on the next GET
  - Alternatives considered: reintroduce Rails flash with an ADR exception
  - Follow-up needed: none unless a later decision explicitly permits flash

- Decision: keep Auth/Core/Side/Palm `/sign/out/complete`
  - Why: those surfaces still complete as RPs on their own hosts; only Base's reloadable
    completion page is retired
  - Alternatives considered: point every RP completion URL at Base `/lobby`
  - Follow-up needed: none

- Decision: Base hosts on `base-rails-rp` register `/lobby`; Side hosts on the same client keep
  `/sign/out/complete`
  - Why: Side still hosts a completion page
  - Alternatives considered: one path for every `base-rails-rp` URI
  - Follow-up needed: none

## Deviations From Plan

- Change: the user-facing request described Rails flash; the implementation uses `SignOutNotice`
  - Why: explicit repository prohibition plus an existing equivalent transport
  - Risk: the one-shot message is a Lobby prop, not a generic flash banner
  - Follow-up: none

## Review Notes

- Tests run: `bin/rails test` (12972 runs, 0 failures, 0 errors, 2 skips), `bun run check`,
  targeted lobby/sign-out/OIDC/route tests
- Tests not run: live browser walkthrough (no browser session in this change)
- Documentation promotion needed: ADR and logout docs updated in the same change
