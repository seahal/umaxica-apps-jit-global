# Dead code search and removal, and what it does to coverage

## What was being verified

Which of the uncovered lines in `app/` and `lib/` are uncovered because the code is dead rather
than untested, and how far removing the dead ones moves line coverage.

## Context

- Repository: `umaxica-apps-global`, branch `feature`, base revision `4ebec1d9d`
- Coverage from `COVERAGE=true bin/rails test` (SimpleCov, `.simplecov`); `config.eager_load = true`
  in the test environment, so every file under `app/` is loaded and no file is uncovered merely
  through never being required
- Date: 2026-09-03

## How the search was done

Four passes, because no single one is reliable on this codebase:

1. `bundle exec debride --rails app lib` - 3566 lines of output, dominated by false positives
   (attribute writers reached through assignment, `eql?` reached through `Hash`, anything resolved
   by Rails convention). Not usable on its own; used only as a cross-check.
2. **Method bodies that never executed.** Merging all 13 SimpleCov worker results and taking every
   method whose body (excluding the `def` line, which runs at load) is entirely uncovered: 104
   methods, 141 lines.
3. **Reference counting.** For each of those, a repository-wide search for the method name outside
   its own definition. Only 2 of 37 distinct names had zero references. The rest are template-method
   overrides a concern calls, so they are live and merely untested.
4. **Routing.** `Rails.application.routes.routes` compared against `ActionController::Base
   .descendants`, keeping concrete controllers that no route names and that nothing subclasses.

Pass 4 is what actually found dead code here, and the pattern it found is consistent: a controller
renamed, the new name routed, the old file left behind.

## Removed

| Removed | Uncovered lines | Why it is dead |
| --- | --- | --- |
| `app/controllers/base/com/oauth/user_info_controller.rb`, `app/controllers/base/org/oauth/user_info_controller.rb` | 6 | No route names them (`config/routes/base.rb` mounts `controller: :userinfos`), nothing references them, and `base/app/oauth` has no such file. They are a weaker copy of the routed `userinfos_controller.rb`: no rate limit, and a bare `render json:` where the routed one calls `render_oauth_bearer_error`. |
| `AuthenticationCredentialInventory#aal2_email_count` | 3 | No callers; a character-for-character duplicate of `aal1_email_count` directly above it. |
| `JitSecurityJwtJwksService.public_keys_for` | 1 | No callers anywhere. |

## Not dead, and deliberately left alone

- `Base::Org::Identity::Revocations::AllsController#create` looked dead - only `#destroy` is routed -
  but the file carries `alias_method :destroy, :create`, so the routed action *is* this method body.
  It is untested, not dead.
- The `set_current_actor` and `set_preferences_cookie` overrides on the three
  `Auth::*::PreferencesBaseController` classes (12 lines) are unreachable: checked at runtime,
  every descendant on every surface (`Web::V0::ThemesController`, `Web::V0::CookiesController`)
  removes both callbacks from its chain. They were **not** deleted, because
  `test/controllers/surface_hook_mapping_test.rb` already encodes them as an intended contract.
  The test was the thing at fault: it replaced `set_preferences_cookie` with a singleton method
  *before* calling it, so the override's own body never ran and the localhost skip it exists to
  perform was never asserted. Two tests were rewritten to drive both overrides for real, which
  covers the 12 lines and makes the existing contract actually hold.
- ~300 classes whose names appear only in their own file are `app/policies/**`,
  `app/validators/**` and jobs - all resolved by convention or configuration, not by reference.

## Still pending approval

Sixteen further concrete controllers have no route, no subclass and no reference, and follow the
same rename-leftover pattern. Deleting them was blocked as too large a destructive action to take
unattended, so they remain in the tree. Together they hold 16 uncovered lines.

- `base/{app,com,org}/edge/v0/dbsc_controller.rb` - the routed DBSC endpoint is
  `base/*/edge/v0/token/dbsc#create`. Note that
  `test/controllers/concerns/dbsc_registration_endpoint_wiring_test.rb` asserts the concern wiring
  against these three unroutable classes rather than against the routed ones, so that test
  currently guards nothing that serves traffic.
- `auth/{app,com}/sign/up/checkpoint/birthdates_controller.rb` - routed birthdates live under
  `sign/up/check/<provider>/birthdates`.
- `core/{app,com,org}/accounts_controller.rb` - `config/routes/core.rb` has no `accounts` route at
  all; the routed accounts are `base/*/accounts` and `auth/org/accounts`. The one uncovered line
  renders `template: "acme/app/accounts/index"`.
- `auth/app/sign/up/check/{apple,email,google,telephone}/cancellations_controller.rb` and
  `auth/com/sign/up/check/{email,telephone}/cancellations_controller.rb` - the only routed
  cancellations are `*/verification/cancellations#create`.
- `base/org/support/{clients,operators}/sessions/emergency_revocations_controller.rb` - only
  `base/org/support/visitors/sessions/emergency_revocations#destroy` is routed.

## Commands run and what was observed

| Command | Observed |
| --- | --- |
| `COVERAGE=true bin/rails test` (before this round) | line 99.07% (53521 / 54021) |
| `COVERAGE=true bin/rails test` (after) | 0 failures, 0 errors, 1 skip; exit 0. Line **99.11%** (53515 / 53991), branch 82.38% (7687 / 9331), method 94.73% (9582 / 10114) |
| `bin/rails test test/controllers/surface_hook_mapping_test.rb` | 10 runs, 61 assertions, 0 failures (was 35 assertions) |
| `bin/rails test` on the units touching the removed methods | 17 runs, 274 assertions, 0 failures |
| `bundle exec rubocop` | 0 offences in 0 files |

Relevant lines fell 54021 to 53991 and covered fell 53521 to 53515: the removed files contained
covered lines too (class and `def` lines run at load), which is why the numerator moved as well.

## Assessment

Dead code is not where this codebase's uncovered lines are. Of 500 uncovered lines, 10 were
removable as dead and a further 16 are pending approval - 5% of the residue. The reference and
routing analyses found nothing else: every other never-executed method body is reached by a concern,
a route, or Rails convention, and is untested rather than dead.

Coverage moved 99.07% to 99.11%. The 99.6% target is not reachable this way. Removing all 26
identified dead lines and covering nothing further would give 53515 / 53975 = 99.15%; reaching
99.6% by deletion alone would require removing roughly 280 uncovered lines of live application code,
which would mean deleting working features.

## Limitations

- The routing analysis assumes a controller with no entry in `Rails.application.routes.routes` is
  unreachable. That holds for HTTP, but a controller invoked some other way (a mailer preview, a
  future route, an engine mount added later) would be misread as dead. Each removal above was
  additionally checked for zero references before it was taken.
- Whether the 16 pending controllers are leftovers or staging for unlanded work was not established
  from history; the judgement rests on the routed sibling existing under the new name.
- Nothing was committed; all changes are left in the working tree.
