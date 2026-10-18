# Remove Code-Side Environment Variable Defaults

Status: backlog. Phase 0 (harness rules and ADR) was completed on 2026-10-06. Phases 1 to 4 are not
started and change no application code yet.

Decision: `adr/env-fetch-without-default.md`.

## Problem

`ENV.fetch("NAME", default)` and its equivalents hide a missing variable behind a call-site value.
The harness rule forbidding it was not enforced, was not loaded for test work, and was scoped to
"required configuration". The ADR records the audit that showed the pattern still growing.

## Baseline

Measured on 2026-10-06 at commit `24739269f464b350e1fa46d2d36474448d0054cb` with uncommitted changes
in the worktree. Counts are lines matching a regular expression; multi-line calls are undercounted.

| Location       | `ENV.fetch` total | With a default     | `ENV[...] \|\|` or `\|\|=` |
| -------------- | ----------------- | ------------------ | -------------------------- |
| `test/`        | 1,880             | 1,027 in 332 files | 27                         |
| `app/`         | 225               | 17                 | 0                          |
| `lib/`         | 21                | 8                  | 1                          |
| `config/*.rb`  | 13                | 12                 | 12                         |
| `config/*.yml` | not counted       | 41                 | not counted                |

Commands used:

```bash
grep -rnIE 'ENV\.fetch\([^()]*,' --include='*.rb' --include='*.rake' --include='*.erb' <dir>
grep -rnIE 'ENV\[[^]]+\]\s*\|\|' --include='*.rb' --include='*.rake' --include='*.erb' <dir>
grep -rcIE 'ENV\.fetch\([^()]*,' config --include='*.yml'
```

Notable groups:

- `test/`: host names dominate. The seven most common defaults account for about 700 lines
  (`PUBLIC_BASE_SERVICE_URL`, `PUBLIC_AUTH_SERVICE_URL`, `PUBLIC_BASE_STAFF_URL`,
  `PUBLIC_BASE_CORPORATE_URL`, `PRIVATE_AUTH_SERVICE_URL`, `PUBLIC_AUTH_CORPORATE_URL`,
  `PUBLIC_AUTH_STAFF_URL`). The same key carries different defaults in different files.
- `app/`: 15 of 17 are `ENV.fetch(KEY, nil)` (11 in `app/values/oidc_client_registry.rb`, one each
  in `app/values/oidc_client_stores_static_client_store.rb`,
  `app/values/regional_rp_client_matrix.rb`, `app/controllers/concerns/social_callback_guard.rb`,
  and `app/helpers/auth/org/sign_ups_helper.rb`). The other two are feature flags:
  `CORE_BROWSER_JWT_COOKIE_ENABLED` in `app/services/core_browser_credential_contract.rb` and
  `IP_ANOMALY_REVOKE_ENABLED` in `app/services/sign_risk_engine.rb`.
- `lib/`: Rake task arguments `REPORT` and `DRY_RUN`, and `UMAXICA_ENV_FILE` in
  `lib/local_environment.rb`.
- `config/`: `SMS_PROVIDER`, `AWS_REGION`, `AWS_SES_REGION`, `RAILS_LOG_LEVEL`, `LOG_LEVEL`,
  `RAILS_PERFORMANCE_ENABLED`, `OPEN_TELEMETRY`, `PORT`, `RAILS_MAX_THREADS`; `ENV[...] ||=` for the
  JWT issuer, audience, and client-id names in `config/initializers/jwt.rb`, for
  `RACK_TIMEOUT_SERVICE_TIMEOUT`, and for `BUNDLE_GEMFILE` and `BOOTSNAP_CACHE_DIR` in
  `config/boot.rb`; `POSTGRESQL_PORT` and `POSTGRESQL_USER` in `config/database.yml`.

## Phase 0 — harness and decision (done 2026-10-06)

- `adr/env-fetch-without-default.md` accepted and indexed in `adr/README.md`.
- `.agents/harnesses/rules/generic/no-silent-fallback.mdc`: environment variable section rewritten
  to cover every Ruby file including tests, with no required/optional exit.
- `.agents/harnesses/rules/generic/testing.mdc`: the forbidden list names the pattern.
- `AGENTS.md`: an always-loaded rule under (C), and the Task Rule Index routes any environment
  variable read, tests included, to `no-silent-fallback.mdc`.

No mechanical enforcement exists after this phase. The rules now reach every session, but nothing
fails when they are ignored.

## Phase 1 — mechanical enforcement

Add a repository cop, `Umaxica/NoEnvDefault`, next to the existing cops in
`lib/rubocop/cop/umaxica/` and register it in `.rubocop/umaxica.yml`.

- Offences: `ENV.fetch` with a second argument, `ENV.fetch` with a block, `ENV[...] || x`,
  `ENV[...].presence || x`, and `ENV[...] ||= x`.
- No autocorrection. Removing a default changes behaviour and needs a person or a reviewed change.
- Include `app/`, `lib/`, `config/`, `db/`, `bin/`, `test/`, and `*.rake`.
- Record current offences with `rubocop --auto-gen-config`-style per-file exclusions in
  `.rubocop_todo.yml` so the cop is green on day one and every new file is covered immediately.
- Pre-commit (`lefthook.yml`) and CI already run RuboCop; no new wiring is needed.
- ERB-templated YAML is outside RuboCop's reach. Cover `config/*.yml` with a `grep`-based CI step or
  convert those reads in Phase 3; decide when Phase 1 starts.
- Keep `Style/FetchEnvVar` disabled and say why in `.rubocop.yml`.

Per `adr/no-test-suite-for-environment-construction.md`, the cop's wiring is verified by running it
and recorded in `evidence/`, not by a Minitest case about configuration. The cop's own detection
logic is ordinary code and is tested as such.

Exit: `bundle exec rubocop` passes, and a scratch file containing each forbidden form fails.

## Phase 2 — tests

Largest group, lowest production risk.

1. List every variable that `test/` reads, and confirm each is set by the environment files that
   `LocalEnvironment.load!` loads for the test run and by the CI job. Add missing ones there.
2. Replace `ENV.fetch("NAME", "default")` with `ENV.fetch("NAME")` directory by directory, removing
   each directory from the exclusion list as it is cleaned. The replacement is mechanical; the review
   effort goes to tests whose default differed from the configured value, because their target host
   changes.
3. Do not introduce a shared host helper. `testing.mdc` forbids test helpers; the one-argument read
   stays in the test body.

Exit: no `test/` entry remains in the exclusion list and `bin/rails test` passes.

## Phase 3 — application, library, and Rake code

1. `ENV.fetch(KEY, nil)` sites: decide per variable whether it is needed (one-argument `ENV.fetch`)
   or optional (`ENV["KEY"]` with an explicit `nil` branch). The OIDC host lists in
   `oidc_client_registry.rb` need this decision per host family.
2. Feature flags: read with one-argument `ENV.fetch` and set the flag explicitly in every
   environment, or move the flag to the mechanism described in `docs/reference/feature-flags.md`.
3. Rake task arguments (`REPORT`, `DRY_RUN`): require them explicitly or convert them to task
   arguments. A destructive task must not default `DRY_RUN` in either direction.
4. `UMAXICA_ENV_FILE` in `lib/local_environment.rb` selects the file that defines the environment,
   so it cannot come from that file. Treat it as optional (`ENV["UMAXICA_ENV_FILE"]` with an explicit
   branch to the standard path) and note the reason at the call site.

Exit: no `app/` or `lib/` entry remains in the exclusion list.

## Phase 4 — configuration and boot

Highest deployment risk; do last and one variable at a time.

1. For each variable, confirm the value is set in production, staging, CI, and the local
   environment files **before** removing its default. Record the confirmation in `evidence/`.
2. Remove the default and deploy. A missing value then fails at boot, which is the intended signal.
3. `config/initializers/jwt.rb` writes defaults into `ENV`. Move those names into the environment
   files and deployment configuration, then delete the assignments.
4. `config/database.yml`: 39 reads share two variables; set them in the environment files and reduce
   the reads to one-argument form.
5. `config/boot.rb` (`BUNDLE_GEMFILE`, `BOOTSNAP_CACHE_DIR`) and `config/puma.rb` (`PORT`,
   `RAILS_MAX_THREADS`) follow Rails-generated conventions that run before the application loads.
   Decide explicitly whether they are converted or recorded as named exceptions in the ADR; do not
   leave them as silent exclusions.

Exit: the exclusion list for the cop is empty, or contains only exceptions named in the ADR.

## Open questions

- Whether the Rails-generated boot and Puma defaults in Phase 4 step 5 are converted or excepted.
- Whether feature flags stay as environment variables at all.
- How `config/*.yml` is checked, given RuboCop does not parse ERB-templated YAML.

## Out of scope

- JavaScript and TypeScript defaults (`process.env.NAME ?? "default"`). The harness rule already
  forbids them; they were not audited here.
- Credential defaults (`Rails.application.credentials.dig(...) || "default"`), likewise forbidden
  and not audited here.
