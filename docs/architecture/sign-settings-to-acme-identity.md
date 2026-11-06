# Auth Settings To Base Identity

## Summary

Auth `/settings` must be limited to credential ceremony-backed settings. Base `/identity` owns
identity, profile, session-management, activity, and account-lifecycle management.

This document replaces the older Sign/Acme migration wording for the current Auth / Base / Core /
Palm vocabulary. Where older code or tests still mention Sign/Acme, read the authority rule as Auth
credential gateway versus Base identity owner unless a current ADR says otherwise.

## Decision

- Auth is the credential gateway and credential ceremony host.
- Base is the Rails foundation/control-plane surface and owns the identity-management body.
- Auth `/settings` is not a general settings, profile, session, activity, or lifecycle surface.
- Base identity routes should use Rails `resource` / `resources` CRUD shapes where practical.
- Compatibility shims are rejected for this migration. Retired Auth settings URLs must become
  unroutable instead of redirecting to Base or returning compatibility responses.

The accepted revision-13 O-11 target allows only these Auth settings entry points:

| Surface | Auth settings routes that may remain                                                                 |
| ------- | ---------------------------------------------------------------------------------------------------- |
| `app`   | ordinary passkey registration; POST-only Google/Apple link starts through the reviewed O-9 admission |
| `com`   | passkeys                                                                                             |
| `org`   | none; Entra sign-in is a separate Auth sign-in ceremony                                              |

Base identity owns these non-ceremony settings:

- emails;
- telephones;
- birthdate;
- secrets and secret credentials;
- sessions and session-set revocation;
- revocations where they are still needed as session/account-management resources;
- activities;
- withdrawal.
- APP TOTP enrollment and management;
- APP social-provider status and unlink;
- ORG's read-only Entra identity status.

The O-11 move is staged. Auth ORG `/settings` and Entra settings routes have been removed; Base ORG
`/identity/social_identities` displays the administrator-provisioned status. APP route removal and
write migration remain incomplete pending the O-9 handoff review and the O-10 write-boundary work.

Do not add Base identity routes named after operation-style Auth settings paths when CRUD resource
shape can express the action. Avoid new `/identity/.../removal`, `/identity/.../revocation`,
`/identity/revocations/all`, `/identity/revocations/others`, `/identity/passkeys/options`, and
`/identity/passkeys/verification` routes for this migration.

Preferred Base identity route shape:

```ruby
namespace :identity do
  resource :settings, only: :show

  resources :emails, only: %i[index new create edit update destroy]
  resources :telephones, only: %i[index new create edit update destroy]
  resource :birthdate, only: %i[show edit update]

  resources :secrets,
            controller: :secret_credentials,
            only: %i[index show new edit create update destroy]
  resources :secret_rotations, only: %i[new create]

  resources :sessions, only: %i[index show destroy]
  resource :session_set, path: "sessions", only: :destroy
  resource :other_sessions, only: :destroy

  resources :activities, only: :index
  resource :withdrawal, only: %i[show new create edit update destroy]
end
```

This shape is guidance, not permission to copy old Auth settings operations into Base. Follow the
current local route convention if it already uses a better resource name.

## No Compatibility Shims

No redirect, alias, or compatibility controller should remain for non-exception Auth settings
routes. In particular:

- do not redirect old Auth settings GET routes to Base identity;
- do not leave mutation routes as `410 Gone` compatibility endpoints;
- do not leave helper aliases so old `auth_*_settings_*` callsites keep compiling;
- do not use Auth controllers as the business-logic body for Base identity.

Tests should prove both sides of the ownership boundary:

- approved credential ceremony-backed Auth settings helpers still exist;
- non-exception Auth settings helpers do not exist;
- non-exception Auth settings paths raise `ActionController::RoutingError`;
- Base identity helpers and path recognition exist for migrated identity resources.

## Scope Notes

- Sign-in, sign-up, step-up, OIDC, social callback, and provider ceremony routes are out of scope
  unless they are directly used as retained Auth settings credential ceremonies.
- App Google and Apple settings remain Auth settings because they are credential/provider
  ceremony-backed settings. Org Entra settings should mirror that pattern without changing the
  existing org Entra sign-in ceremony route.
- `com` keeps only Auth passkey settings.
- `app` keeps only Auth passkey, TOTP, Google, and Apple settings.
- `org` keeps only Auth passkey and Entra settings.
- `mfa/reset` and `mfa/challenge` are not general Auth settings exceptions. If a retained
  passkey/TOTP settings ceremony cannot work without an equivalent interaction, fold it into the
  retained credential resource's `new`/`create` flow or document the narrow exception before keeping
  it.
- `operator_lifecycle_requests` must not be moved casually under Base identity. It is also not an
  approved Auth settings exception. If the correct owner is unclear during implementation, remove it
  from the Auth settings migration scope only with an explicit TODO explaining the unresolved owner
  and tests proving it was not accidentally blessed as Base identity.

## Implementation Guardrails

- Start with characterization tests before moving production code.
- Create Base identity tests first and observe red failures before adding routes or controllers.
- Preserve Auth credential ceremony routes for sign-in, sign-up, and step-up flows that are outside
  this migration.
- Replace all non-exception Auth settings helpers and hard-coded `/settings/...` callsites with Base
  identity helpers.
- Do not place business logic in controllers while moving the surface. Extract shared domain code
  only when needed by the Base controller.
- Auth settings route contract tests must become regression guards for the matrix above.

## Current Implementation Notes

As of 2026-07-01, `bin/rails routes -g settings` and `bin/rails routes -g identity` cannot complete
in the current worktree because route loading fails with duplicate route name `auth_app_root` from
`config/routes/auth.rb`. Resolve or account for that boot blocker before trusting route inventories
in the migration PR.

Existing code already contains some Base identity controllers and Auth settings redirect shims.
Those shims conflict with this document and should be treated as migration debt, not as accepted
compatibility behavior.
