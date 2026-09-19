# Action Policy controller audit — 2026-09-18

Baseline commit `5fc90f8d0`, action_policy 0.7.7 (Gemfile.lock).

## Method

- Route-driven inventory via `bin/rails runner`: every routed `controller#action`, its resolved
  `authentication_mode_for`, and whether `authorize!` appears in any app file defining a method in
  the controller's ancestor chain.
- Gem source check (`action_policy-0.7.7/lib/action_policy/rails/controller.rb`): instance
  `verify_authorized` raises `UnauthorizedAction` when `authorize_count` is zero; `authorized_scope`
  only bumps `scoped_count`; `allowed_to?` bumps neither.
- `AuthenticationBase` already installs `after_action :verify_private_action_authorized!`, which
  calls `verify_authorized` for every `:private` action.

## Inventory result

779 routed controller classes, 1253 route-action pairs (deduplicated per class/action below).

| Mode                    | Actions     | `authorize!` reachable | none reachable |
| ----------------------- | ----------- | ---------------------- | -------------- |
| private                 | 409         | 401                    | 8              |
| open                    | 329         | 157                    | 172            |
| guest                   | 97          | 0                      | 97             |
| no `AuthenticationBase` | 374 classes | —                      | —              |

The 374 classes outside `AuthenticationBase` are health, revision, JWKS, discovery, OAuth
token/revocation/userinfo, OIDC callback/backchannel, MCP liveness, public content
(docs/help/info/news), redirect-only `Auth::*` shims, the token-authenticated email unsubscribe, and
framework engines (ActiveStorage, ActionMailbox, Turbo).

## Private actions without authorization (8)

- `Base::{Com,Org}::Identity::RotationsController#create`: the RED test raised
  `ActionPolicy::UnauthorizedAction: Action 'base/{com,org}/identity/rotations#create' hasn't been authorized`
  for the owner. Fixed with `authorize!(secret, to: :update?)`, the same rule the destination edit
  page applies. After the fix: 6 runs, 16 assertions, 0 failures.
- `Base::{App,Com,Org}::WelcomesController#show` and
  `Auth::{App,Com,Org}::Sign::In::ChecksController#show`: sign-in ceremony steps gated with
  `allowed_to?`. Deferred with a TODO. The render path was not exercised in this session; the
  existing welcome test covers only the redirect path.

## Emergency pre-check not reaching controller requests

Probe (throwaway integration test, removed afterwards) on `POST /identity/secrets/:id/rotation`
(org) with an operator token whose `authentication_context` is `emergency`:

- The JWT claims were
  `{"scope" => "authenticated domain:operator read:org", "authn_ctx" => "emergency"}`.
- `ApplicationPolicy#deny_capability_restricted_context` saw rule `:update?` and `current_token`
  `nil`.
- Call order: `load_from_token` installed the claims (`authn_ctx` present). Then `set_current_actor`
  replaced `Actor.authz.token_claims` with `nil`.
- Response: 303 to the edit page, so the Emergency operator was allowed.

Cause: `ActorSupport#resolved_current_token` calls `load_access_token_payload`
(`PreferenceAccessTokenTransport`, the preference JWT loader), which returns a boolean. Not fixed:
the fix narrows live Emergency access across surfaces and needs an explicit decision. A TODO is left
at the method.

## Pre-existing failures at baseline (unrelated, not touched)

`bin/rails test` at baseline: 13311 runs, 1 failure, 2 errors, 4 skips.

- `OidcAccessTokenAuthenticatorNoRpSessionLookupTest` (source-text match on `*RpSession`).
- `ObservabilityGatewayContractTest` x2 (`assert_not_includes` / `assert_not_empty` undefined).

## After change

`bin/rails test`: 13317 runs, 80989 assertions, 1 failure, 2 errors, 4 skips. The same three
pre-existing failures as the baseline; the 6 new rotation tests pass. `rubocop` on the 11 changed
files: no offenses.

## 2026-09-19: Emergency pre-check fix and Step-Up gates

- Fix: `AuthenticationBase#load_from_token` now records the verified payload, and
  `ActorSupport#resolved_current_token` returns it. RED before the fix: an Emergency operator got
  `303` to the rotation edit page. GREEN after the fix.
- Step-Up gates added. RED was confirmed by removing each gate: the refusal tests failed, and they
  passed again once the gate was restored.
  - App: MFA reset `create` (`settings_mfa`).
  - App: secrets `edit`/`update`/`destroy` (`settings_secret_credential`).
  - App: emails `edit`/`update`/`destroy` (`settings_email`).
  - Com/Org: removals `create` (`settings_secret_credential`).
- Emergency policy changed by owner decision: `permits_rule?` now passes Normal and Emergency and
  denies unknown contexts. `EMERGENCY_PERMITTED_RULES` is removed. Emergency is restricted only by
  Step-Up gates (GitHub issue #884).
- High items from #884 were not gated. Organization memberships (app/com/org) are stubs with no
  state change, and App groups are a JSON API on a surface without Emergency sessions.
- `bin/rails test`: 13324 runs, 81011 assertions, 1 failure, 2 errors, 4 skips. These are the same
  three pre-existing failures as the baseline. `rubocop` on the 31 changed files: no offenses.
