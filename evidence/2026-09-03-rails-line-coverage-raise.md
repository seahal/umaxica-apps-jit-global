# Raising Rails line coverage toward 99.6%

## What was being verified

Whether `bin/rails test` line coverage can be brought from its measured 99.05% to 99.6%, and what
the remaining uncovered lines actually are.

## Context

- Repository: `umaxica-apps-global`, branch `feature`, base revision `4ebec1d9d`
- Ruby 4.0.6, Rails 8.2.0.alpha; coverage from `COVERAGE=true bin/rails test` (SimpleCov, `.simplecov`)
- Date: 2026-09-03

## The arithmetic of the target

| | Lines |
| --- | --- |
| Relevant lines | 54021 |
| Covered at start | 53512 (99.05%) |
| Covered now | 53521 (99.07%) |
| Needed for 99.6% | 53805 |
| Still needed | 284 |
| Uncovered remaining | 500 |

99.6% therefore requires covering 284 of the 500 lines that remain, or 57% of the residue. The
denominator cannot be moved usefully by deletion: covering nothing and deleting instead would
require removing 294 uncovered lines of application code.

## What was done

Six tests were added, covering 9 lines. Each was checked to exercise a real branch rather than to
colour a line.

| Test file | Covers | Behaviour pinned |
| --- | --- | --- |
| `test/lib/object_storage_shrine_configuration_modes_test.rb` | `lib/object_storage_shrine_configuration.rb:68,114,139,141` | An unknown storage mode is refused by both builders instead of defaulting; the production S3 storage is built from the configured region and refuses an endpoint |
| `test/services/sign_up_state_machine_dispatch_test.rb` | `app/services/sign_up_state_machine.rb:139,218,222` | A social callback carrying a hand-off skips the checkpoint; a stopped hand-off does not transition; an unrecognised hand-off status is refused |
| `test/middleware/trusted_forwarded_headers_test.rb` | `lib/trusted_forwarded_headers.rb:32` | A peer address that cannot be parsed is untrusted and its forwarding headers are stripped |
| `test/unit/jit/security/jwt/jwks_test.rb` | `lib/jit_security_jwt_jwks.rb:36` | JSON that parses but is neither a JWK Set object nor an array is refused rather than yielding an empty key set |
| `test/services/redirects/jump_gateway_url_test.rb` | `app/services/redirects_jump_gateway_url.rb:51,52` | A plain-http gateway origin is allowed only on a local host name |
| `test/values/oidc_client_registry_host_helpers_test.rb` | `app/values/oidc_client_registry.rb:247,290` | An unparsable host is not public; the client surface falls back to the service host list |

Measured gain was 9 lines, not the 11 targeted: two of the targeted lines were already reached by
another path in the full run.

## Where the remaining 500 lines are

| Area | Lines | Files |
| --- | --- | --- |
| `app/controllers/auth` | 161 | 67 |
| `app/controllers/base` | 136 | 78 |
| `app/controllers/concerns` | 105 | 64 |
| `app/services` | 36 | 25 |
| `lib` | 16 | 10 |
| `app/operations` | 12 | 7 |
| `app/values` | 10 | 7 |
| everything else | 24 | 19 |

The residue has no large targets left: the worst single file misses 15 lines, 156 files miss
exactly one, and 71 miss two. Covering all 99 lines outside `app/controllers` would still leave
185 to find inside controllers, behind authentication, region-redirect and turnstile guards.

## Uncovered because it is dead, not because it is untested

Three sites were checked and found unreachable, which is why no test covers them. They are
reported rather than removed, since removing application code was not the task.

- `app/controllers/{auth/app,auth/com,auth/org}/preferences_base_controller.rb` — the
  `set_current_actor` and `set_preferences_cookie` overrides, 12 lines. Both subclasses on every
  surface (`web/v0/themes_controller.rb`, `web/v0/cookies_controller.rb`) carry
  `skip_before_action` for exactly these two callbacks, so no route reaches either override.
- `app/controllers/base/{com,org}/oauth/user_info_controller.rb` — 6 lines. Nothing references
  either class and no route names it: `config/routes/base.rb` mounts
  `resource(:userinfo, only: :show, controller: :userinfos)`, and `base/app/oauth` has no
  `user_info_controller.rb` at all, so these two are leftovers of the rename.
- `app/queries/authentication_credential_inventory.rb:187-191` — `aal2_email_count`, 3 lines, has
  no callers and is a character-for-character duplicate of `aal1_email_count` above it.

## Commands run and what was observed

| Command | Observed |
| --- | --- |
| `COVERAGE=true bin/rails test` (before) | 12153 runs, 0 failures, 0 errors, 1 skip; line 99.05% (53512 / 54021) |
| `COVERAGE=true bin/rails test` (after) | 12162 runs, 66839 assertions, 0 failures, 0 errors, 1 skip; 1132.8s; exit 0. Line **99.07%** (53521 / 54021), branch 82.27% (7680 / 9335), method 94.64% (9576 / 10118) |
| `bin/rails test` on each of the six touched files | all pass, 0 failures |
| `bundle exec rubocop` | 0 offences in 0 files |

The two `oidc_client_registry` tests were written after the measured run began and so are not in
its figures; they pass, and their 2 lines are additional to the 99.07% recorded above.

## Assessment

**The target was not reached.** Coverage moved 99.05% to 99.07%. 284 further lines are required
for 99.6% and they are spread over 277 files at one to three lines each, so the work is roughly
150-200 more tests of the kind written here, most of them controller tests requiring authenticated
sessions per surface. This is a multi-session effort, not a remaining step of this one.

Nothing was claimed that was not measured, and no line was covered by deleting code, by asserting
on a mock instead of behaviour, or by invoking a method purely to reach it.

## Limitations

- The per-file worklist for the remaining 500 lines exists only as the analysis above; it was not
  written to the repository.
- Whether every one of the 500 is reachable at all was not established. Three sites totalling 21
  lines were checked and are not; the rest were not individually audited, so the ceiling that real
  tests can reach is unknown and may be below 99.6% without removing dead code.
- Nothing was committed; all changes are left in the working tree.
