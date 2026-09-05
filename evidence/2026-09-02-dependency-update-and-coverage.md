# Dependency update, coverage thresholds, and implementation audit

## What was being verified

That the test suites pass before and after a full package update, that both coverage gates
(SimpleCov for Ruby, Vitest v8 for TypeScript) are met on the updated tree, and whether the
application carries performance or security defects worth fixing.

## Context

- Repository: `umaxica-apps-global`, branch `feature`, revision at start `4ebec1d9d`
- Host: Linux, ruby 4.0.6, bundler 4.0.17, node v24.19.0, pnpm 12.0.0
- PostgreSQL reached over the podman network (`primary`, `replica`); Valkey at `valkey:6379`
- Date: 2026-09-02

## Step 1 - baseline before any update

| Command | Observed |
| --- | --- |
| `bin/rails test` | 12151 runs, 66771 assertions, 0 failures, 0 errors, 1 skip; 814.6s; exit 0 |
| `pnpm test:coverage` | exit 0; statements 99.54%, branches 99.03%, functions 98.80%, lines 99.81% |

`bin/rails test` alone measures no coverage: `test/test_helper.rb:3` starts SimpleCov only when
`COVERAGE=true`, so the baseline above is a pass/fail baseline and every coverage figure in this
record comes from a `COVERAGE=true` run.

The one skip is pre-existing: `test/integration/oidc_rp_browser_flow_test.rb:345`, blocked on
issue #846. Two further conditional skips exist but did not fire in this environment.

## Step 2 - package update

`bundle update` (exit 0) and `pnpm update` (exit 0). Exactly what moved:

| Package | From | To |
| --- | --- | --- |
| `rails` (git, branch `main`) | `4130768a1b0d95da640ac792920e54988cf2d12f` | `7d3b098615d01563bdab9909cbc2048ab5012e54` |
| `sorbet`, `sorbet-runtime`, `sorbet-static`, `sorbet-static-and-runtime` | 0.6.13454 | 0.6.13455 |

Nothing else moved. `propshaft` and `flipper` (also sourced from git) were already at their
branch heads. `pnpm update` reported "Already up to date" and `pnpm outdated` reported nothing,
so no JavaScript dependency was behind its declared range; `pnpm-lock.yaml` is unchanged. The
only JS-side change was `node_modules` re-syncing `lefthook` 2.1.10 to 2.1.12, which the catalog
in `pnpm-workspace.yaml` already pinned.

No major version was crossed, so no compatibility change was needed. `bin/rails runner` booted
against the new Rails revision and reported `Rails 8.2.0.alpha` before the suite was run.

## Step 3 - coverage on the updated tree

`COVERAGE=true bin/rails test` - 12151 runs, 66764 assertions, 0 failures, 0 errors, 1 skip;
1162.6s; exit 0. Exit 0 is the result that matters: SimpleCov's checks run at exit, so every
`minimum`, `minimum_per_file`, `minimum_per_group` and `maximum_drop` in `.simplecov` passed.

| Metric | Measured | `minimum` | `maximum_drop` baseline |
| --- | --- | --- | --- |
| Line | 99.05% (53508 / 54017) | 97 | 99.05, drop 0.00 (limit 0.2) |
| Branch | 82.19% (7673 / 9335) | 80 | 82.16, rose 0.03 (limit 0.5) |
| Method | 94.62% (9573 / 10117) | 93 | n/a |

`pnpm test:coverage` - exit 0; statements 99.54%, branches 99.03%, functions 98.80%,
lines 99.81%, against the flat threshold of 98 for all four in `vitest.config.ts`. Functions is
the narrowest margin at 743/752; nine more uncovered functions would breach it.

No test had to be written: both gates were already met on the updated tree.

## Step 4 - implementation audit

Scanners, all run on the updated tree:

| Check | Result |
| --- | --- |
| `bundle exec brakeman` | 0 security warnings, 0 errors, over 771 controllers / 557 models / 89 templates |
| `bundle exec bundler-audit check --update` | No vulnerabilities found (advisory db at commit `0a02e5f`, 1237 advisories) |
| `pnpm audit --audit-level=low` | No known vulnerabilities found |
| `bundle exec rubocop` (incl. `-performance`, `-thread_safety`) | 5 offences in 5 test files; 0 after the fix below |
| `pnpm lint` (oxlint) | exit 0 |
| `pnpm typecheck` (tsc --build) | exit 0 |
| `pnpm deadcode` (knip) | exit 0 |
| `pnpm format:check` (oxfmt) | exit 0, 570 files |

Manual checks that found nothing to fix:

- N+1: structurally prevented rather than absent. `config/environments/{test,development}.rb`
  set `strict_loading_by_default = true` with `action_on_strict_loading_violation = :raise`,
  and Prosopite is active in controller tests.
- Request state in class variables, globals or `Thread.current`: no occurrences in `app/` or `lib/`.
- Secrets in logs: log sites pass identifiers, outcomes and `error_class`, not tokens, cookies or
  parameters.
- Timing-safe comparison: 20 comparison sites over tokens, digests, OTPs, JKTs and PKCE
  challenges all route through `ActiveSupport::SecurityUtils.secure_compare`. The one raw `==`
  on a name ending in `_code` (`app/models/concerns/enforcement_appeal.rb:56`) compares a
  resolution status string, not a secret.
- OTP expiry: `verify_otp_code` does not check expiry itself, but reaches the record only through
  `OtpLockable#get_otp`, which returns nil when expired or locked (`otp_lockable.rb:73`).
- Missing indexes: 87 `%_id` columns across 10 databases have no index with that column leading.
  Each candidate that sits on an authentication hot path was checked against the code that queries
  it, and none is actually queried by that column - `client_passkeys.external_id` is never a
  predicate (lookups use the uniquely indexed `webauthn_id`), `client_authorization_codes.client_id`
  likewise (lookups use the uniquely indexed `code`), and `turnstile_replays.ceremony_id` likewise
  (`token_digest`, unique). Every column the hot auth path does select on - `public_id`,
  `refresh_token_digest`, `dbsc_session_id`, `dbsc_session_id_digest`, `oidc_jti`, `oidc_sid`,
  `device_session_id`, `refresh_token_family_id` - is indexed. No index was added.

### Correction on the one thing that looked like a defect

RuboCop reported `Minitest/NonPublicTestMethod` on four `test "..." do` blocks that sit lexically
after a `private` in their class body, which reads as four tests that never run - three of them
authorization tests, one covering WebAuthn relying-party equality. This was checked rather than
assumed, by running one file at its committed revision and again after the fix:

```
git show HEAD:test/unit/webauthn/relying_party_config_test.rb  ->  11 runs, 30 assertions
after moving the test above `private`                          ->  11 runs, 30 assertions
```

The tests were already running. Rails' `test` helper calls `define_method` from inside its own
method frame, so the class body's default visibility does not reach the method it defines, and
the cop is a false positive for this form. The full-suite count is unchanged at 12151 either way,
which independently confirms it. No dead test existed and no production defect was behind one.

### What was changed

Only the RuboCop offences, so that `bundle exec rubocop` exits 0 rather than always exiting 1:

- `test/controllers/base/{app,com,org}/organizations/memberships_controller_test.rb` - moved the
  trailing `test "show returns empty json for a membership the actor may read"` above the `private`
  section of the reopened class.
- `test/unit/webauthn/relying_party_config_test.rb` - moved
  `test "configs compare by relying party id and origin, not by identity"` above `private`.
- `test/services/sign_up_state_machine_terminal_test.rb:29` - `assert ..., status_name` passed a
  bare status name where `assert`'s second argument is the failure message, which is what
  `Minitest/AssertWithExpectedArgument` flags as ambiguous. Replaced with an explicit message.

These are behaviour-preserving. No application code was changed, because the audit found nothing
in it that warranted a change.

## Final verification

| Command | Observed |
| --- | --- |
| `bin/rails test` (5 touched files) | 40 runs, 79 assertions, 0 failures, 0 errors, 0 skips |
| `bundle exec rubocop` | 0 offences in 0 files |
| `pnpm test:coverage` | exit 0; statements 99.54%, branches 99.03%, functions 98.80%, lines 99.81% |
| `COVERAGE=true bin/rails test` | 12151 runs, 66703 assertions, 0 failures, 0 errors, 1 skip; 1115.9s; exit 0. Line 99.05% (53508 / 54017), branch 82.18% (7672 / 9335), method 94.64% (9575 / 10117) - every `.simplecov` gate passed |

## Assessment

PASS. The suites pass on the updated tree and both coverage gates are met with margin on every
metric. The audit produced no performance or security fix, and this record deliberately says so
rather than manufacturing one: the scanners are clean, the N+1 and index questions were checked
against the code that would suffer from them, and the single lead that looked like a real defect
was disproved by measurement.

Three `COVERAGE=true bin/rails test` runs were made in total - one after the package update
and one on the final tree, plus the pass/fail baseline before it. Line coverage held at 99.05%
across all of them; branch moved 82.16 -> 82.19 -> 82.18 and method 94.62 -> 94.64, which is
run-to-run variance from the parallel seed, far inside the 0.2 and 0.5 `maximum_drop` limits.

## Limitations

- `bundle exec database_consistency` could not be run. Version 3.0.11 calls the deprecated
  `ActiveRecord::Base.connection` (`lib/database_consistency/helper.rb:50`), which raises under
  Rails 8.2.0.alpha, so it aborted before checking anything and its missing-index and
  null-constraint findings are unavailable. The index question was answered by direct catalog
  queries instead, as described above, which covers indexes but not the model-versus-column
  validation checks the gem also performs.
- `pnpm run check` was not run in full: its `openapi:verify` step regenerates
  `public/openapi.*.yml` in the working tree. Its components `format:check`, `lint`,
  `typecheck` and `deadcode` were run individually and passed.
- The audit is a scanner-plus-targeted-reading pass over 2458 application files, not an
  exhaustive review. Absence of findings here is weaker evidence than the passing gates above.
- Nothing was committed; all changes are left in the working tree.
