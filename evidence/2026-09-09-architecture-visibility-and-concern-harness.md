# Architecture harness: method visibility and concern inclusion hooks

Date: 2026-09-09

## What was verified

Two custom RuboCop cops were added (`lib/rubocop/cop/umaxica/`) with a generated debt baseline
(`.rubocop_todo.yml`, `.rubocop/architecture_baseline.yml`) and a ratchet test
(`test/tooling/architecture_baseline_test.rb`).

- `bundle exec rubocop --only Umaxica` — 4753 files inspected, no offenses (baseline absorbs the
  existing debt).
- `bin/rails test test/tooling/umaxica_architecture_cops_test.rb test/tooling/architecture_baseline_test.rb`
  — 17 runs, 3248 assertions, 0 failures, 0 errors.
- `bundle exec rubocop` (whole repository) — 9 offenses, all pre-existing in files not touched by
  this work (`test/controllers/**/healths_controller_test.rb` line length,
  `test/lib/entra_omniauth_boot_credentials_test.rb` parentheses).

Baseline recorded at the end of the work:

- `Umaxica/NoConcernInclusionHooks` — 99 offenses across 99 files.
- `Umaxica/ExplicitMethodVisibility` — 3700 offenses across 1508 files.

## Harness self-tests performed

- A new file with an implicitly public `def call` and a new concern with `included do` were both
  reported by `bundle exec rubocop --only Umaxica` (2 offenses, 2 files). Probe files were deleted.
- An extra implicitly public method added to an already-baselined file
  (`app/services/operator_secret_credentials_create.rb`) failed the ratchet test:
  "3 offenses, baseline allows 2". The edit was reverted.

## Production code migrated

`app/models/concerns/identity.rb` — the `included do validates :status_id, numericality: ... end`
hook was removed and the validation declared directly in the three host classes (`Client`,
`Operator`, `Visitor`), next to their `attribute :status_id` default. Baseline counts dropped
accordingly (100 -> 99 hooks, 3701 -> 3700 implicit-public).

## Not verified

The Rails test suite (model tests for `Client`/`Operator`/`Visitor`, and `bin/ci`) could not run in
this environment: booting the application requires environment variables and a reachable PostgreSQL
instance provided by compose (`config/initializers/omniauth.rb` raised `KeyError:
PUBLIC_AUTH_SERVICE_URL`, and with `compose.env` loaded the adapter could not reach host `primary`).
The tooling tests above run without a database and did execute.
