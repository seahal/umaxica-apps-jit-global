# Environment Variables Are Read Without Code-Side Defaults

Accepted: 2026-10-06

## Context

`ENV.fetch("NAME", default)` turns a missing variable into a value chosen at the call site. The
process keeps running, and the mistake surfaces later and somewhere else: a request sent to the
wrong host, a feature silently switched off, a test that passes against a host nobody configured.

`.agents/harnesses/rules/generic/no-silent-fallback.mdc` has forbidden this since 2026-06-29. An
audit on 2026-10-06 (commit `24739269f464b350e1fa46d2d36474448d0054cb`, counted by line-level
regular expression, so multi-line calls are undercounted) found the rule was not holding:

| Location       | `ENV.fetch` with a default | `ENV[...] \|\|` or `\|\|=` |
| -------------- | -------------------------- | -------------------------- |
| `test/`        | 1,027 in 332 files         | 27                         |
| `app/`         | 17                         | 0                          |
| `lib/`         | 8                          | 1                          |
| `config/*.rb`  | 12                         | 12                         |
| `config/*.yml` | 41                         | not counted                |

The pattern kept growing after the rule existed. Between 2026-06-30 and the audit, `test/` gained
840 such lines and lost 650; `app/` gained 25 and lost 13.

The defaults had already drifted from the configured values and from each other. In `test/`,
`PUBLIC_BASE_SERVICE_URL` defaulted to `"base.app.localhost"` in 209 places and to
`"www.app.localhost"` in 14. `PRIVATE_BASE_SERVICE_URL` defaulted to `"www.app.localhost"` in 27
places while the checked-in environment files set it to `base.app.localhost`.

Four causes explain why a written rule did not hold:

1. **Nothing enforced it.** No RuboCop cop, pre-commit job, or CI step detects the pattern.
2. **The rule was not loaded where the violations were written.** The Task Rule Index routed it to
   configuration, security, and routing work. A session writing tests loaded `testing.mdc`, which
   did not mention environment variables.
3. **The wording left an exit.** The rule spoke of "required configuration", which let a test host
   name or a feature flag be read as "not required" and therefore out of scope.
4. **Existing code taught the opposite.** More than a thousand call sites are a stronger example
   than a paragraph of prose.

## Decision

Ruby code in this repository never supplies a substitute value for an environment variable at the
point where the variable is read.

1. **A variable the code needs is read with one-argument `ENV.fetch("NAME")`.** A missing variable
   raises `KeyError` at that line.
2. **A variable that is legitimately optional is read with `ENV["NAME"]`**, and the `nil` case is
   handled as a named, explicit branch (do nothing, disable the feature, raise). The branch must not
   produce a substitute value for the variable.
3. **The following forms are forbidden everywhere**, with no distinction between "required" and
   "optional" variables:
   - `ENV.fetch("NAME", anything)`, including `ENV.fetch("NAME", nil)`
   - `ENV.fetch("NAME") { ... }`
   - `ENV["NAME"] || value`, `ENV["NAME"].presence || value`, and equivalents
   - `ENV["NAME"] ||= value`
4. **The scope is every place Ruby is evaluated:** `app/`, `lib/`, `config/` (including
   ERB-templated YAML such as `config/database.yml`), `db/`, `bin/`, Rake tasks, and `test/`. Test
   code is not exempt.
5. **Values come from the environment, not from code.** Development and test values live in the
   checked-in environment files loaded by `LocalEnvironment.load!`; a variable a test needs is added
   there, once.
6. **Existing violations are debt, not precedent.** New and edited code follows this decision even
   when neighbouring lines do not.
7. **RuboCop's `Style/FetchEnvVar` stays disabled.** Its autocorrection rewrites `ENV["NAME"]` to
   `ENV.fetch("NAME", nil)`, which is a form this decision forbids, and the editing hook runs
   `rubocop -A`.

Enforcement is mechanical. A repository cop will reject the forbidden forms in pre-commit and CI,
with the existing call sites recorded as a shrinking exclusion list. Until that cop exists, the
harness rules are the only control; see `plans/backlog/env-fetch-default-removal.md`.

## Consequences

- A missing variable fails at boot or at the first line that reads it, with the variable name in the
  error, instead of producing wrong behaviour downstream.
- Each variable has one value per environment. The disagreement between call-site defaults
  disappears because call sites no longer carry values.
- A test run with an incomplete environment fails loudly. That is intended: the environment file is
  the thing to fix.
- Operational knobs that today default in code (`PORT`, `RAILS_MAX_THREADS`, `RAILS_LOG_LEVEL`,
  `SMS_PROVIDER`, the AWS regions, the JWT issuer and audience names) must be set in every
  environment, including production, before their defaults are removed. The migration plan orders
  that work so no deployment loses a value it currently relies on.
- Rake task arguments passed through the environment (`REPORT`, `DRY_RUN`) lose their defaults and
  must be passed explicitly or become real task arguments.

## Alternatives considered

- **Keep the prose rule and tighten its wording only.** Rejected as the sole measure: the audit
  shows wording does not survive a thousand counter-examples without a check that fails.
- **Allow defaults in tests.** Rejected. Tests are where the values had drifted furthest, and a test
  that silently targets an unconfigured host verifies nothing about the configured one.
- **Allow defaults for "optional" variables.** Rejected. The required/optional distinction is the
  loophole that let the pattern spread; an optional variable is expressed by its `nil` branch.
- **Enable `Style/FetchEnvVar`.** Rejected; see decision 7.
