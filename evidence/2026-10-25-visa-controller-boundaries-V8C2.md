# Visa controller boundaries and action visibility

Revision: `bde2346c17e2aa911acc95de1f6035f80498f2da`. The worktree already held extensive staged
and unstaged authentication, schema, refresh and logout changes. Results include that state and
this uncommitted controller refinement. No migration, deployment or external write was performed.

## Change

- APP/COM/ORG authorization endpoints and eight result/cancellation/switch endpoints now inherit
  realm-local `AuthorizationBaseController` classes instead of another concrete endpoint.
  Each base uses Rails `abstract!`, defaults to deny-all, and hides its show/create implementations.
  Authorization explicitly exposes show/create; continuations expose only show. Public framework
  `action_methods` tests assert these exact sets, excluding inherited lifecycle helpers.
- Actor lookup, finalization, Root issuance and realm-specific Switch behavior stay in their own
  realm. A source comparison against the starting indexed controllers confirmed that extracted
  private implementations are identical after excluding indentation and comments.
- Protocol rate limiting and callback order are retained. Concrete endpoints register request-size
  validation; the existing region-canonicalization exemption moves to the three protocol bases
  without changing its effective endpoints. No authentication/CSRF/rate-limit skip was introduced.
- Visa action visibility is explicit, with no remaining measured Visa architecture offenses.
  Both architecture artifacts were generated using `ArchitectureBaseline.measure/write`, retaining
  the starting non-Visa entries and recording only Visa reductions: 46 removed entries each.
  A full regeneration initially picked up unrelated worktree debt; those non-Visa changes were
  excluded using the same writer rather than absorbing new offenses into the baseline.
- Tests for redirect conformance and root-cookie checks now target Visa rather than Base.
  COM/ORG region-parameter tests exercise the implemented navigation GET start rather than the
  retired intermediate POST form. The ownership guard checks edge check/refresh declarations on
  Visa and their absence on Base. Passive proper-name-only roots have explicit region exemptions.
- The Visa ADR, durable authentication checklist and cycle ledger describe the delivered boundary.

## Verification

- Starting six-file baseline: 26 tests, 87 assertions, four failures and four errors.
  Failures were the eight concrete-controller inheritances (one guard), the three root region
  exemptions (one guard), and two stale COM/ORG form-start expectations. Errors were the three
  cases in `OidcResultCsrfTransportTest` and the case in `OidcResultBrowserBindingTest`, which
  dereference forms no longer returned by authorization GET.
- Final combined request/browser/security run: **111 tests, 1,405 assertions, zero
  failures/errors/skips**. Command: `bin/rails test` with these files:
  - `test/integration/{visa_authorization_continuations,base_same_origin_handoff,oidc_initiated_sign_in_completion,oidc_rp_browser_flow,root_login_establishment_flow,visa_roots,unknown_host_root}_test.rb`
  - `test/controllers/base/{oauth_redirect_uri_conformance,edge_v0_token_checks}_test.rb`
  - `test/controllers/base/{com,org}/oauth/authorizations_controller_test.rb`
  - `test/unit/security/{ri_routing_contract,authentication_mode_inventory,forbidden_rails_patterns,standard_csrf_invariant,identity_authority_inversion_guard}_test.rb`
  - `test/security/invariants/csrf_verification_strategy_invariant_test.rb`
  - `test/controllers/{controller_inheritance_invariant,controller_base_inheritance}_test.rb`
  Braces abbreviate the actual file arguments. Coverage includes all eight continuation endpoints,
  missing navigation metadata, HEAD refusal, parameter sizes 2,047/2,048/2,049 bytes, total query
  sizes 8,191/8,192/8,193 bytes, exact action exposure, successful sign-in, session limits and replay.
- Same six-file baseline comparison: 26 tests, 91 assertions, zero failures and the same four form
  errors. Those two historical receiver-test files were preserved; no acceptance was waived.
- RuboCop: **94 files, zero offenses**, covering all 86 Visa controllers, the result-post concern,
  the new continuation test and six updated tests. Scoped `git diff --check` passed.
- Full architecture guard: three tests, 1,706 assertions, two failures outside Visa. The first
  reports unrecorded visibility debt starting at `app/models/op_app_authority_stop.rb`; the second
  reports the stale resolved `app/services/sign_up_suspension.rb` entry. Their baseline entries
  were not expanded or edited to conceal failures.

## Remaining scope and failed checks

An intermediate broader 14-file protocol run completed 208 tests/1,029 assertions with 31 failures,
no errors/skips. It included old form/result-receiver expectations, old Base-host conformance
requests and the old Base edge-check request. The migrated conformance/edge/COM/ORG files later
passed separately (24 tests/197 assertions) and in the final 111-test run. The entire 208-test set
was not rerun, so remaining broad failures are unverified, not declared resolved or regression-free.
The full Rails suite, external Jump integration and complete WU-02 acceptance were not executed.
An initial guard invocation named a nonexistent FQDN order test and did not run; the corrected
existing guard set is included in the final results above.
