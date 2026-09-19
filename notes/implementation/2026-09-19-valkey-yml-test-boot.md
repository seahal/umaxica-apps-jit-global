# Valkey yml and test boot Implementation Notes

## Context

- Original plan/spec: conversation request to introduce `config/valkey.yml` and make
  `bundle exec rails test` / `bun vitest run` work without hand-exported Valkey URLs.
- Related decisions/docs/plans: `adr/valkey-nonprod-logical-db-topology.md`,
  `adr/no-test-suite-for-environment-construction.md`
- Implementation date: 2026-09-19

## Decisions Made During Implementation

- Decision: load `config/valkey.yml` through `Umaxica::Valkey::Settings` rather than
  scattering `Rails.env.test?` connection logic. Production uses `url_key` only.
  - Why: matches `database.yml` and keeps DB indexes in one file.
  - Alternatives considered: `Rails.application.config_for` only. Coverband configures
    before the application instance is ready, so Settings reads the YAML file directly.
  - Follow-up needed: none.

- Decision: keep `scripts/test-isolated` as an optional claim/cleanup wrapper.
  - Why: still useful for explicit recovery; no longer the boot contract.
  - Alternatives considered: delete the script. Kept because scoped cleanup on exit
    remains useful.

## Deviations From Plan

- Change: test rate-limit default is namespaced Valkey, with MemoryStore still available
  via `with_rate_limit_counters`.
  - Why: the request required real Valkey for rate-limit in test, while existing
    rate-limit cases still time-travel a MemoryStore.
  - Risk: every test setup SCAN/DELs the worker prefix; suite time may increase.
  - Follow-up: measure if SCAN-per-test is too expensive.

## Review Notes

- Tests run: pending in this note; recorded in `evidence/` after execution.
- Tests not run: Compose file edits (out of scope).
- Documentation promotion needed: ADR amendment and operations docs updated in this change.
