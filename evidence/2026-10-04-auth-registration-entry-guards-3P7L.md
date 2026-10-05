# Authentication registration entry guards

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication implementation and concurrent unrelated changes. No commit, deployment or new database migration.
- Database: owned isolated run `20261003auth6f3`, manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, preparation selected the isolated APP ticket copy, one worker. Rails commands ran sequentially.

The initial public-entrypoint/forbidden-pattern checks found undocumented setup admission routes
and a new TOTP registration callback skip. The unnecessary skip was removed, leaving the inherited
verification callback and explicit scoped registration authorization in place. The existing skip
allowlist shrank by the five Auth cancellation/Email controllers already replaced with scoped
admission. The setup inventory now identifies only the reviewed surface controllers, paths,
actions and methods; documentation explains the exact bootstrap and ownership requirements.

`bin/rails test test/unit/security/public_entrypoint_inventory_test.rb test/unit/security/forbidden_rails_patterns_test.rb test/unit/security/ri_routing_contract_test.rb test/controllers/auth/route_naming_test.rb test/integration/totp_registration_boundary_test.rb`
passed: **32 runs, 447 assertions, no failures/errors/skips**, seed 24805.

Session-limit cancellation formerly redirected to Auth without a new Base admission. A controller
test reproduced that wrong destination. Cancellation now closes the waiting flow and returns to
the same-origin Base neutral entry, retaining existing tokens and clearing the browser locator.
`bin/rails test test/controllers/base/app/sign/in/limitations_controller_test.rb test/integration/local_authentication_boundary_test.rb`
passed: **12 runs, 129 assertions, no failures/errors/skips**, seed 63049.

An `entry_ref` canary reproduced an unfiltered opaque admission parameter. It is now explicitly
filtered alongside the existing ceremony result keys.
`bin/rails test test/unit/security/filter_parameter_logging_test.rb` passed:
**4 runs, 28 assertions, no failures/errors/skips**, seed 43356. This proves the Rails parameter
filter behavior, not all proxy/trace/job logging. OTP mail/job logging remediation remains excluded.

RuboCop passed on the five changed controller/guard tests and separately on the parameter-filter
initializer/test. `git diff --check` passed.

The required broader root-login gate was executed:
`bin/rails test test/controllers/concerns/auth/session_issuance_boundary_surfaces_test.rb test/controllers/concerns/auth/login_cooldown_surfaces_test.rb test/integration/root_login_establishment_flow_test.rb`.
It is **not green: 58 runs, 199 assertions, 1 failure, 4 errors, no skips**, seed 16366.
Failures are in the existing admission-free Auth Email integration file; its
helpers still expect Auth session issuance and Auth session-limit routes. That file requires
purpose-correct Base/Auth/Base migration preserving all seven scenarios. This does not prove
those scenarios work or excuse implementation failures. The held APP Email JSON success contract
remains unresolved; no Auth root fallback was restored.

The additional Passkey candidate persistence and Auth success response shape are proposed in
`plans/analysis/passkey-registration-base-candidate-shape-proposal.md` and await explicit approval.
No implementation of those unapproved fields or response changes was performed. Full R01–R16,
browser, live-provider, independent-connection races and fault injection remain incomplete.
