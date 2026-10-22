# Environment wiring observation for retired initializer tests — 2026-10-22

Commit: `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`. The worktree carried pre-existing uncommitted
changes in production code, tests, configuration and documentation; none of them touched
`config/initializers/flipper.rb`, `config/initializers/rack_timeout.rb` or
`config/initializers/prosopite.rb`.

This record replaces `test/initializers/flipper_test.rb`, `test/initializers/rack_timeout_test.rb`
and `test/initializers/prosopite_test.rb` (findings LV-021, LV-022 and LV-023 in
`research/2026-10-22-test-value-audit/findings.md`), which covered tool wiring that
`.agents/harnesses/rules/project/no-environment-tests.mdc` keeps out of the test suite.

## Command

`bin/rails runner -e development` with a script that printed the values below. Development boot
reached the configured PostgreSQL and Valkey services.

## Observed

| Subject | Observation |
| --- | --- |
| Flipper adapter in development | `Memoizable -> Strict -> ActorLimit -> ActiveRecord` |
| Flipper model pools | writing role resolves to `primary`; reading role resolves to `primary` |
| Flipper read inside `connected_to(role: :reading)` | `fqdn_available_auth_corporate` read `true` without `ConnectionNotDefined` |
| Flipper stored features | 42 |
| Rack::Timeout middleware | `Rack::Timeout` present in the development middleware stack |
| `RACK_TIMEOUT_SERVICE_TIMEOUT` after boot | `"10"` |
| Prosopite middleware | `Prosopite::Middleware::Rack` present in development |
| `Prosopite.fingerprint` inside the reading role | completed; `ActiveRecord::Base.current_role` was still `reading` afterwards |
| Role outside that block | `writing` |

## Not observed

- No request was held past the Rack::Timeout limit. Only middleware installation and the effective
  ENV value were observed, so timeout enforcement itself is not established here.
- `config/initializers/rack_timeout.rb` assigns a code-side default (`||= "10"`), which conflicts
  with the repository rule against code defaults for configuration. It was left unchanged; the
  conflict is recorded here and is not resolved.
- Production boot was not run.
