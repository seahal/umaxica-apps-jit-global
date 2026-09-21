# Phase 04 Opaque OIDC Result POST Transport

## Scope

This record covers the Base/Auth browser OIDC result transport slice on branch `feature` at
HEAD `52efa31df2a28763ad405f604bb3ef0c416b3b93`. The working tree already contained 136
user-owned modified or untracked paths before this record was added; no unrelated changes were
staged, reverted, committed, or sent to GitHub.

The slice establishes an explicit Auth handoff page and removes the obsolete OIDC transaction
resume-URL API. It does not complete the later Base callback/RP-credential authority migration.

## Implemented contract

- Auth `GET /sign/oidc/handoff` only renders a continuation form.
- Auth `POST /sign/oidc/handoff` is same-origin and Rails-CSRF protected; it registers the
  authenticated actor and issues the one-shot, surface-bound opaque result.
- Auth renders a second form that submits the result in the body to the matching Base
  `POST /oauth/authorize` endpoint.
- Base result consumption is not available through `GET /oauth/authorize?result=...`.
- Base keeps the existing Rails forgery-protection strategy and applies the exact configured Auth
  origin (plus the existing same-site/null-origin proxy case) to the cross-surface result POST.
- Auth handoff actions require the surface actor and existing Client/Visitor/Operator `show?`
  policy; no authorization callback was bypassed.
- The old `OidcAuthorizationTransactionCoordinator` `resume_url` value and model-level
  `acme_resume_url` helper were removed so the retired query transport cannot be revived through
  that API.

## RED/GREEN history

The first full-suite run after the initial transport implementation was:

```text
11366 runs, 72581 assertions, 3 failures, 0 errors, 5 skips
```

The failures identified two stale integration expectations for the old redirect/result-query
flow and two new handoff views missing the repository page-title declaration. A focused rerun also
exposed missing Action Policy authorization on the new private handoff actions. Those findings were
fixed by updating the public-flow assertions, adding page-title declarations, and applying the
existing surface authentication/policy boundary.

## Verification performed

Focused Rails tests after the final code change:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
PARALLEL_WORKERS=1 bin/rails test \
  test/integration/oidc_initiated_sign_in_completion_test.rb \
  test/security/opaque_result_transport_test.rb \
  test/unit/views/page_title_presence_test.rb \
  test/services/oidc_authorization_transaction_service_test.rb \
  test/models/model_only_line_coverage_test.rb
```

Result: `45 runs, 365 assertions, 0 failures, 0 errors, 0 skips`.

Focused RuboCop over the 17 changed Ruby files: `17 files inspected, no offenses detected`.

Final Rails suite:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
bin/rails test
```

Result: `11365 runs, 72587 assertions, 0 failures, 0 errors, 5 skips`.

Additional read-only checks confirmed that the result routes include POST actions for all three
surfaces, the Base controllers retain `protect_from_forgery using: :header_or_legacy_token`, the
result action has exact trusted-origin configuration, and no production `acme_resume_url` or
`issuance.resume_url` call remains. `git diff --check` passed.

## Not verified or changed

- Live external Auth/Base hosts and Cloudflare/Tunnel behavior were not exercised by this slice.
- No production or shared database was reset; no migration or external configuration was changed
  by this slice.
- The remaining legacy Base `resume_authorization!` path still uses the generic Base `log_in`
  session issuance path. Removing that second root-session creation is a later authority-boundary
  slice and is not claimed as complete here.
- The five existing full-suite skips remain; they were not added or changed by this slice.
