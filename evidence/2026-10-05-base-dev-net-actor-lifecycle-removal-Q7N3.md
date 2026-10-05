# Base developer and network faces: actor lifecycle removal, tests not run

Date: 2026-10-05

Commit: `e8f2371bc5cbefd2087c728aeeef4e318463d33f`. The change itself is uncommitted, and the
worktree also held unrelated uncommitted App Secret work at the time.

## Result

**Not verified.** No Minitest or Vitest run was performed for this change. The repository owner
directed that tests not be run in this session because another agent was using the test
environment, and approved proceeding without them as a one-time exception. The behavior of the
changed controllers after the change has therefore not been observed.

## What changed

- `app/controllers/base/dev/application_controller.rb` and
  `app/controllers/base/net/application_controller.rb`: removed `Session`, `ActorSupport`,
  `Finisher`, `helper_method :current_actor`, `before_action :set_current_context`,
  `before_action :reset_flash`, and `prepend_around_action :with_actor_lifecycle`.
- `test/controllers/concerns/application_controller_common_patterns_test.rb`: added `base/dev` and
  `base/net` to the excluded paths. No test case was deleted.

The reasoning is in `adr/oidc-oauth-participation-allowlist-and-non-participant-surfaces.md`.

## What was checked

- `ruby -c` on the three files above reported `Syntax OK`. This checks syntax only.
- Static reading, by `grep` and file inspection: each controller is inherited only by its
  `RootsController`; neither root view or action reads `current_actor` or `Actor`;
  `FqdnAvailabilityGate`, `RateLimit`, and `DefaultNoStore` contain no `Actor` reference; no test
  other than the pattern test above names these callbacks for `Base::Dev` or `Base::Net`.

## Tests still to run

- `test/controllers/concerns/application_controller_common_patterns_test.rb`
- `test/controllers/controller_base_inheritance_test.rb`
- `test/security/invariants/default_no_store_policy_invariant_test.rb`
- `test/controllers/base/dev/roots_controller_test.rb`
- `test/controllers/surface_default_web_rate_limit_test.rb`
- `test/integration/default_no_store_base_test.rb`, which requests both the `base.dev.localhost`
  and `base.net.localhost` hosts
- `test/integration/html_title_contract_test.rb`, which lists the Base network host
