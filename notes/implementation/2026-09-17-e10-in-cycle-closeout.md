# E10 in-cycle closeout implementation notes

## Context

- Original plan/spec: repository-root `refactor.md` E10; `misc.md` current-cycle relationship column
- Related: MISC-0001–0016; evidence/2026-09-17-e10-closeout.md
- Implementation date: 2026-09-17

## Decisions Made During Implementation

- Decision: prefer new assertions on existing production entry points over production edits.
  - Why: coordinator/Lua/authorization/OTP/logout already implemented the fail-closed contracts.
  - Follow-up: physical DPoP, SimpleCov branch/method floors, GUID persistence owner.

- Decision: keep CODE_TTL (10s) and T0 as `Time.utc(2026, 1, 2, 3, 4, 5)` from the issuer helper.
  - Why: wall-clock JWT decode rejects time-travelled January tokens; Lua TTL rejects hour-scale
    T1/T2 gaps.

## Deviations From Plan

- Change: ordinary Rails / SimpleCov / `bin/ci` not claimed green this session.
  - Why: architecture baseline fails on unrelated dirty rails_performance files; worktree preserved.
  - Risk: coverage gap remains the last measured red SimpleCov dimensions.

## Review Notes

- Tests run: focused isolated twice (182/951); E1 public subset (94/417); JS 1057; JS coverage; bun
  check; Brakeman; bundler-audit.
- Tests not run: COVERAGE=true Rails, canonical `bin/ci`, physical DPoP.
