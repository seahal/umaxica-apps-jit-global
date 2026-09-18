# Operator Rack app hosts — development access verification

Scope: the four Rack apps mounted on dedicated hosts (`mission`, `flipper`, `blazer`, `pghero`),
reached from inside the development container over `*.core.dev.localhost:3001` (a second
`bin/rails server` started for the check; the session's own server on :3000 was left alone).

## Changes verified

- Development HTTP Basic credentials set to `admin` / `pass`:
  `.env`, `.env.example`, `.env.devcontainer.example`, `.env.local` for
  `FLIPPER_UI_*`, `BLAZER_*`, `PGHERO_*`; `mission_control.http_basic_auth_{user,password}` in
  `config/credentials/development.yml.enc`.
- `PGHERO_USER` / `BLAZER_USER` renamed to `PGHERO_USERNAME` / `BLAZER_USERNAME`: both gems read
  those exact names for their own built-in Basic Auth filter, and `PGHERO_PASSWORD` set without
  `PGHERO_USERNAME` made `http_basic_authenticate_with name: nil` raise
  `ArgumentError (Expected name: to be a String, got NilClass)` while the controller class loaded.
- `pghero` / `blazer` requires moved from `config/initializers/*` to `config/application.rb`: an
  engine contributes its `config/routes.rb` through the `add_routing_paths` initializer, which has
  already run by the time `config/initializers/*` load, so the engines were mounted with an empty
  route set (`PgHero::Engine.routes.routes.size == 0`) and every request fell through to
  `UnknownHostsController#show`.
- Blazer/PgHero mounted directly instead of wrapped in `Rack::Auth::Basic`; the credential check
  moved into each engine's own middleware stack (`Engine.middleware.use Rack::Auth::Basic`), still
  fail-closed when credentials are blank. A wrapped engine is not recognised as a Rails app by
  `mount`, which broke its PATH_INFO handling.
- `config.solid_queue.connects_to` gained `reading: :queue` in development and production; Mission
  Control Jobs reads through the `reading` role and raised
  `ActiveRecord::ConnectionNotDefined (No database connection defined for SolidQueue::Record with
  'reading' role)`.
- `bin/rails assets:precompile` re-run: this application resolves assets through Propshaft's static
  manifest, so `pghero/favicon.png` (and the other engine assets) had to enter
  `public/assets/.manifest.json`; the manifest is read at boot, so the server needed a restart.
- `PUBLIC_*_URL` / `PRIVATE_*_URL` for the four hosts added to `.env`, which is the only file
  `LocalEnvironment.load!` reads. Without them a server started from a shell that had not exported
  them matched no host constraint and answered `{"error":"unknown_host"}`.

## Results (curl, `*.core.dev.localhost:3001`)

| host | no credentials | wrong credentials | `admin:pass` |
| --- | --- | --- | --- |
| mission | 401 | 401 | 200 |
| flipper | 401 | 401 | 302 (to `/features`) |
| pghero | 401 | 401 | 302 `/` → 200 `/publishing`, 200 `/primary` |
| blazer | 401 | 401 | 500 |

Blazer remains broken, and not because of routing or credentials: its UI needs the `blazer_queries`
/ `blazer_dashboards` tables, and the request fails with
`ActiveRecord::StatementInvalid (PG::UndefinedTable: relation "blazer_queries" does not exist)`.
No migration was added — the existing `config/initializers/blazer.rb` comment records a deliberate
decision to keep Blazer table-free, so resolving this needs a decision, not a silent schema change.

## Prosopite exemption for Mission Control Jobs

`MissionControl::Jobs::RecurringTasksController#index` and `JobsController#index` raised
`Prosopite::NPlusOneQueriesError` (per-key `solid_queue_recurring_tasks` lookups, 1000-row
`solid_queue_jobs` pages). Those queries are in gem code, so `config/initializers/prosopite.rb` now
sets `Prosopite.allow_stack_paths = [%r{/mission_control-jobs-}]` — configuration only, no
middleware and no patching. Prosopite matches that list against the raw `caller_locations`, so gem
frames match; the exemption is keyed on the stack path, not on the Solid Queue tables.

Verified after a server restart, with `admin:pass`:

- `/applications/jit/recurring_tasks?server_id=solid_queue` — 200 (was 500).
- `/applications/jit/finished/jobs?server_id=solid_queue` — 200 (was 500).
- `/finished/jobs`, `/failed/jobs`, `/in_progress/jobs`, `/applications/jit/queues`, `/` — 200.
- `log/prosopite.log` stayed at 6493 lines across all of those requests: nothing reported.
- Detection elsewhere is intact: `Prosopite.scan { 3.times { SolidQueue::Job.where(id: _1).first } }`
  in `bin/rails runner` still raises `Prosopite::NPlusOneQueriesError`, and
  `Prosopite.allow_stack_paths` holds only the one regex with `Prosopite.raise?` still true.
- `bin/rubocop config/initializers/prosopite.rb` — no offenses.

## Tests

- `bin/rails test test/config/host_authorization_contract_test.rb test/integration/unknown_host_root_test.rb`
  — 7 runs, 56 assertions, 0 failures.
- `bin/rails test test/tooling/evidence_layout_test.rb` — 3 runs, 6 assertions, 0 failures.
- The full suite was not run.
