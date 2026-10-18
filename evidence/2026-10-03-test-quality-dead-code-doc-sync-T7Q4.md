# Test quality, dead code, and documentation synchronization pass

Performed on 2026-10-03 against commit `b74017b518986b2dd9caca1ad411204176f62079`. The worktree
already carried 36 uncommitted files (the RuboCop cleanup recorded in
`2026-10-03-rubocop-offense-cleanup-L4N8.md`); the "before" figures include them and the "after"
figures add this task's uncommitted changes. Nothing was committed.

## Coverage

Rails, `COVERAGE=true bin/rails test test/`:

| Metric | Before                 | After                  | Delta    | `.simplecov` minimum |
| ------ | ---------------------- | ---------------------- | -------- | -------------------- |
| Line   | 96.32% (60924 / 63253) | 96.36% (60834 / 63131) | +0.04 pt | 98                   |
| Branch | 74.82% (7877 / 10528)  | 74.92% (7887 / 10528)  | +0.10 pt | 93                   |
| Method | 92.02% (10281 / 11172) | 92.34% (10301 / 11155) | +0.32 pt | 97                   |

- Before: 12586 runs, 85442 assertions, 0 failures, 0 errors, 2 skips; SimpleCov exit 2.
- After: 12624 runs, 85418 assertions, 0 failures, 0 errors, 1 skip; SimpleCov exit 2.
- SimpleCov exits 2 in both runs because all three metrics were already below their minimums. No
  threshold, filter, or exclusion was changed.
- Files below their per-file floor fell from 35 to 22; no file newly fell below its floor.

Vitest, `bun run test:coverage`:

| Metric     | Before | After  | Threshold |
| ---------- | ------ | ------ | --------- |
| Statements | 99.40% | 100%   | 99        |
| Branches   | 97.56% | 99.66% | 99        |
| Functions  | 98.76% | 99.86% | 99        |
| Lines      | 99.53% | 100%   | 99        |

- Before: 87 files, 1081 tests passed; exit 1 (branches and functions under threshold).
- After: 91 files, 1101 tests passed; exit 0.

## Other gates

| Command                           | Before       | After         |
| --------------------------------- | ------------ | ------------- |
| `bin/rubocop`                     | no offenses  | no offenses   |
| `bundle exec erb_lint --lint-all` | no errors    | no errors     |
| `bun run format:check`            | 3 files fail | same 3 files  |
| `bun run typecheck`               | 2 errors     | same 2 errors |
| `bun run lint`                    | config error | not re-run    |
| `bun run deadcode` (knip)         | exit 0       | exit 0        |
| `bun run openapi:lint`            | valid        | not re-run    |
| `bin/rails zeitwerk:check`        | not run      | all good      |
| `bin/brakeman --quiet --no-pager` | not run      | exit 5        |
| `git diff --check`                | not run      | clean         |

Brakeman's exit 5 is its out-of-date exit (8.0.6 installed, 8.1.0 available). It printed only that
notice and no scan report, so no Brakeman result was obtained in this session.

The format failures are `src/features/self_service/AvatarForm.tsx`,
`src/pages/auth/org/sign/in/passkeys/new.tsx`, and `src/pages/base/org/avatars/show.tsx`. The
typecheck errors are in `spec/features/dashboards/base_dashboard_identity.test.tsx` and
`src/pages/base/org/avatars/show.tsx`. `bun run lint` fails before linting because oxlint finds a
nested `.oxlintrc.json` in the untracked `tmp/rails-jump-staged-e2zhgv_1/` directory; the new specs
were linted directly with `oxlint -c .oxlintrc.json` and are clean. None of these were changed.

## Tests added

- `test/models/authority_cutover_marker_test.rb`: the Agent, Bureau, Company, Enterprise, and
  Individual cutover markers are created once, replay without a second row, and reject update and
  destroy; each lifecycle is active only in the `active` state.
- `test/models/rp_session_retirement_window_test.rb`: the retirement window at leeway minus one
  second, at the leeway, and one second after it; monotonic Access JWT expiry bookkeeping.
- `test/services/group_avatar_membership_authorization_test.rb`: detach and reorder refusals for a
  wrong surface, a foreign or missing account scope, a non-owner, a removed membership, an archived
  group, and diverged owners; position 0 and non-integer positions.
- `spec/features/auth/ceremony_cancellation.test.tsx`,
  `spec/features/base_org/admin_record_behavior.test.tsx`,
  `spec/pages/auth/app/settings/totp_enrollment_start.test.tsx`,
  `spec/pages/base/app/sign/in/limitation_binding.test.tsx`.

## Removed as dead

Each has no route, no subclass, and no reference outside tests; routing was compared against
`ActionController::Metal.descendants` with `bin/rails runner`, and `config/routes/` draws nothing
conditionally.

- `Core::{App,Com,Org}::RobotsController`, `Core::{App,Com,Org}::SitemapsController`, and
  `app/views/core/{app,com,org}/sitemaps/show.xml.builder`.
  `test/controllers/core/route_naming_test.rb` and `test/controllers/public_robots_routing_test.rb`
  already assert Core serves neither path.
- `Core::Org::ConfigurationsController`. It has no route, no subclass, and no reference, which is
  the reason it was removed.
  - Correction from the follow-up review on 2026-10-03: this record first called it "an unrouted
    copy of the routed `Base::Org::ConfigurationsController`". That was wrong. The two differ: the
    Core class rendered `acme/org/roots/index`, the Base class answers `head :not_implemented`.
    Duplication was never the basis for removal.
- `Auth::{App,Com,Org}::Sign::In::Check::CancellationsController`.
- `Base::{App,Com,Org}::Oauth::JwksController`. Four route contract tests assert `/oauth/jwks` is
  retired. The `Base::App::BareController` pinned descendant list lost one entry.
- `OidcRpLogout` concern, included by no controller, and its harness-only test.
- Fourteen helper modules with no methods under `app/helpers/{core,help,news}/`.
- `test/services/branch_coverage_batch8_more_services_test.rb`: every case called its subject with a
  wrong signature and rescued the resulting `ArgumentError`, or skipped, so no production method
  body ran.

Stale entries for the removed files were dropped by hand from `.rubocop_todo.yml`,
`.rubocop/architecture_baseline.yml`, and the exception list in
`test/unit/security/action_policy_usage_test.rb`.

## Not completed

- A repository-wide scan matching never-executed methods against name references was refused by the
  session's permission classifier and was not retried by other means. Dead-method findings therefore
  come from targeted, per-candidate searches only.
- Most uncovered controller-concern code remains uncovered; see the session report for the list.
