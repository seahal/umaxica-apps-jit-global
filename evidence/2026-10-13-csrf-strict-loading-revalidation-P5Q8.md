# Base/Auth CSRF and strict-loading revalidation

Work performed on branch `feature` against full HEAD
`aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`. The worktree was dirty with the ongoing plan and
other edits; unrelated work was preserved. Implementer: Codex, GPT-6, default session effort.
`one.md` and `two.md` remain unchanged. The user selected the stricter Base/Auth CSRF contract,
recorded as CHG-005 in `three.md`.

Every unsafe request on the Base/Auth application and Base authority boundaries requires a valid,
session-bound Rails authenticity token even when Fetch Metadata is same-origin. Rails' standard
Origin, Fetch Metadata, hybrid token strategy, and GET/HEAD/QUERY exemptions remain in place. No
Rails verification method was overridden and no cross-surface concern was introduced.

Strict-loading violations discovered in Base/Auth admission, ceremony binding, Browser RP logout,
preference persistence, email lookup, and refresh-token issuance were addressed at their read
owners with explicit relations, eager loading, or typed owner queries. Refresh-token rotation keeps
the in-memory device-session association aligned with its persisted current-token update, and
refresh-reuse audit resolves its actor through the token's fixed owner type.

Verification used only the standard Rails `test` configuration with
`POSTGRESQL_ISOLATED_TEST_RUN_ID` unset and `PARALLEL_WORKERS=1`; no database reset, migration, or
isolated fleet was used. The combined CSRF, admission, OIDC result, route coverage, preference, and
refresh-token regression selection passed: 128 runs, 1,069 assertions, 0 failures, 0 errors, and
0 skips. The exact command selected the following files:

```text
test/security/invariants/csrf_verification_strategy_invariant_test.rb
test/security/invariants/csrf_acceptance_override_invariant_test.rb
test/unit/security/standard_csrf_invariant_test.rb
test/controllers/auth/admission_csrf_transport_test.rb
test/integration/org_admin_csrf_test.rb
test/controllers/base/oidc_result_csrf_transport_test.rb
test/controllers/security/csrf_route_coverage_test.rb
test/integration/preference_web_csrf_test.rb
test/integration/preference_logout_downgrade_test.rb
test/controllers/base/{app,com,org}/api/v0/preferences/{cookie,theme}_controller_test.rb
test/models/concerns/refresh_tokenable_test.rb
test/models/concerns/refresh_token_shared_test.rb
```

RuboCop passed on the 19 affected Ruby files. `git diff --check` passed. No full Rails or Vitest
suite was run for this follow-up, so the earlier full-suite strict-loading diagnostic remains the
only broad diagnostic; this evidence does not claim its unrelated violations are resolved.
