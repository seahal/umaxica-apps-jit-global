# Side shared browser client retirement revalidation

Date: 2026-09-22

Repository: `seahal/umaxica-apps-jit-global`

HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`

Worktree: dirty before and after this verification. Existing local changes were preserved; no
commit, push, GitHub write, or external service configuration change was performed.

## Scope

The local `side-rails-rp` static registration and builder were removed after a repository call-path
audit found no production runtime caller. Side uses the independent `side-app`, `side-com`, and
`side-org` registrations. The remaining `sign-rp`, `base-rails-rp`, and `core-next-rp` shared
browser registrations were not retired because their migration and external registration status
remain separate gates.

## TDD and verification

The first full-suite run after removing the local registration exposed one stale characterization
expectation:

```text
OidcSevenFirstPartyRpClientsTest#test_deprecated_shared_browser_clients_remain_findable_until_seven_flows_are_proven
Expected nil to be present? for side-rails-rp
```

The test was updated to assert that `side-rails-rp` is absent while the three remaining shared
browser clients remain findable until their separate retirement gate closes. No production behavior
was restored to satisfy the obsolete expectation.

Focused command:

```text
PARALLEL_WORKERS=1 bin/rails test test/values/oidc_seven_first_party_rp_clients_test.rb test/services/oidc/client_registry_test.rb test/services/oidc/authorize_service_test.rb
```

Focused result: `67 runs, 430 assertions, 0 failures, 0 errors, 0 skips`.

Static checks:

```text
bundle exec rubocop app/values/oidc_client_stores_static_client_store.rb test/services/oidc/client_registry_test.rb test/services/oidc/authorize_service_test.rb test/values/oidc_seven_first_party_rp_clients_test.rb
git diff --check
```

Result: RuboCop inspected 4 files with no offenses; `git diff --check` passed.

Full-suite command:

```text
bin/rails test
```

Full-suite result: `11530 runs, 73418 assertions, 0 failures, 0 errors, 8 skips`.

The suite emitted expected test-provider and framework diagnostic output, including OmniAuth test
failures and Rails deprecation warnings handled by existing tests; none produced a test failure or
error. Skips were not added or changed as part of this slice.

## Unverified boundaries

External RP registration/key retirement, deployed callers outside this repository, and live
Cloudflare/AWS/provider behavior were not contacted and remain unverified. This evidence records
local registry and test behavior only.
