# `included do` Mapping Table for Concerns

> Status: reference snapshot. This document is not the controller lifecycle source of truth. Use
> `docs/architecture/controller-lifecycle.md` for current lifecycle rules.

This document describes the side effects introduced by `included do` blocks inside
`app/controllers/concerns/`.

## Mapping Table

| #   | File                                       | Contents of `included do`                                                                                                                                                                                                                                                                                                                           | Dependencies                               |
| --- | ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| 1   | `authentication/base.rb:861-872`           | `include ::Sign::ErrorResponses`<br>`include ::SessionLimitGate`<br>`rescue_from LoginCooldownError`<br>`helper_method :current_account, :current_session_public_id`                                                                                                                                                                                | Sign::ErrorResponses, SessionLimitGate     |
| 2   | `authentication/client.rb:17-23`           | `helper_method :current_client, :logged_in?, :active_client?, :logged_in_client?`<br>`alias_method :current_client, :current_resource`<br>`alias_method :authenticate_client!, :authenticate!`<br>`alias_method :logged_in_client?, :logged_in?`<br>`include ::AuthorizationAudit`                                                                  | AuthorizationAudit                         |
| 3   | `authentication/operator.rb:17-25`         | `helper_method :current_operator, :logged_in?, :active_operator?, :logged_in_operator?`<br>`alias_method :current_operator, :current_resource`<br>`alias_method :authenticate_operator!, :authenticate!`<br>`alias_method :logged_in_operator?, :logged_in?`<br>`before_action :transparent_refresh_access_token`<br>`include ::AuthorizationAudit` | AuthorizationAudit                         |
| 4   | `authentication/visitor.rb:17-23`          | `helper_method :current_visitor, :logged_in?, :active_visitor?, :logged_in_visitor?`<br>`alias_method :current_visitor, :current_resource`<br>`alias_method :authenticate_visitor!, :authenticate!`<br>`alias_method :logged_in_visitor?, :logged_in?`<br>`include ::AuthorizationAudit`                                                            | AuthorizationAudit                         |
| 5   | `authentication/viewer.rb:10-13`           | `helper_method :current_viewer`                                                                                                                                                                                                                                                                                                                     | -                                          |
| 6   | `authorization_audit.rb:9-16`              | `include Common::Redirect`<br>`rescue_from ActionPolicy::Unauthorized`                                                                                                                                                                                                                                                                              | Common::Redirect                           |
| 7   | `sign/error_responses.rb:16-25`            | `include Common::Redirect`<br>`rescue_from ActionPolicy::Unauthorized`<br>`rescue_from ApplicationError`<br>`rescue_from ActionController::InvalidCrossOriginRequest`                                                                                                                                                                               | Common::Redirect                           |
| 9   | `sign/org_verification_base.rb:18-22`      | `helper_method :verification_viewer`<br>`before_action :load_verification_viewer`<br>`before_action :verify_verification_viewer`                                                                                                                                                                                                                    | -                                          |
| 10  | `sign/app_verification_base.rb:23-28`      | Same as above (app version)                                                                                                                                                                                                                                                                                                                         | -                                          |
| 11  | `sign/com_verification_base.rb:152-157`    | `helper_method :verification_com_user`<br>`before_action :load_verification_com_user`                                                                                                                                                                                                                                                               | -                                          |
| 12  | `sign/email_registrable.rb:32-40`          | `helper_method :email_registrable?`<br>`before_action :load_registration_session`<br>`before_action :verify_registration_session`                                                                                                                                                                                                                   | -                                          |
| 13  | `sign/email_registration_flow.rb:11-17`    | `helper_method :email_registration_url`<br>`before_action :load_registration_flow`<br>`before_action :verify_registration_flow`                                                                                                                                                                                                                     | -                                          |
| 14  | `sign/telephone_registrable.rb:8-12`       | `helper_method :telephone_registrable?`<br>`before_action :load_telephone_registration_session`                                                                                                                                                                                                                                                     | -                                          |
| 15  | `sign/staff_telephone_registrable.rb:8-12` | Same as above (staff version)                                                                                                                                                                                                                                                                                                                       | -                                          |
| 16  | `sign/edge_v0_json_api.rb:8-13`            | `helper_method :edge_v0_json_api?`<br>`before_action :set_edge_v0_json_api_format`                                                                                                                                                                                                                                                                  | -                                          |
| 17  | `preference/base.rb`                       | None. Controllers must register `before_action :set_preferences_cookie` explicitly where needed.                                                                                                                                                                                                                                                    | -                                          |
| 18  | `preference/core.rb`                       | None. Preference controllers must register `before_action :ensure_preferences_record` explicitly where needed.                                                                                                                                                                                                                                      | -                                          |
| 19  | `preference/edge.rb`                       | None. Controllers must declare public/open behavior explicitly.                                                                                                                                                                                                                                                                                     | -                                          |
| 20  | `preference/web_cookie_actions.rb`         | None. Controllers must include `Preference::WebCookieEndpoint` and callback skips explicitly where needed.                                                                                                                                                                                                                                          | -                                          |
| 21  | `preference/web_theme_actions.rb`          | None. Controllers must include `Preference::WebThemeEndpoint` and callback skips explicitly where needed.                                                                                                                                                                                                                                           | -                                          |
| 22  | `preference/regional.rb`                   | None. Controllers must register preference, canonicalization, locale, timezone, and theme callbacks explicitly where needed.                                                                                                                                                                                                                        | -                                          |
| 23  | `preference/global.rb`                     | None. Controllers must register helper methods explicitly if views need controller-provided helpers.                                                                                                                                                                                                                                                | Preference::Base, Preference::Localization |
| 24  | `preference/localization.rb`               | None. Controllers must register `before_action :apply_localization_preferences` explicitly where needed.                                                                                                                                                                                                                                            | -                                          |
| 25  | `preference/adoption.rb`                   | None. Adoption methods are called explicitly from preference/authentication flows.                                                                                                                                                                                                                                                                  | -                                          |
| 26  | `actor_support.rb`                         | None. `set_current_context` / `set_current_actor` / `set_current_observability` / `_reset_current_state` / `with_actor_lifecycle` are called only by explicit controller callbacks.                                                                                                                                                                 | -                                          |
| 27  | `minimum_response_budget.rb:7-9`           | `after_action :enforce_minimum_response_budget`                                                                                                                                                                                                                                                                                                     | -                                          |
| 28  | `social_auth.rb:31-36`                     | `helper_method :social_auth_providers`<br>`before_action :load_social_auth_config`                                                                                                                                                                                                                                                                  | -                                          |
| 29  | `social_callback_guard.rb:29-32`           | `before_action :verify_social_callback_state`                                                                                                                                                                                                                                                                                                       | -                                          |
| 30  | `oidc/callback.rb:8-11`                    | `helper_method :oidcCallback`<br>`before_action :verify_oidc_callback`                                                                                                                                                                                                                                                                              | -                                          |

## Side-Effect Categories

### 1. Including other modules (implicit dependencies)

- `include Common::Redirect` (authorization_audit, sign/error_responses)
- `include Sign::ErrorResponses` (authentication/base)
- `include SessionLimitGate` (authentication/base)
- `include AuthorizationAudit` (authentication/client/operator/visitor)

### 2. helper_method registration (availability from views)

- `current_account`, `current_client`, `current_operator`, `current_visitor`, `current_viewer`
- `logged_in?`, `logged_in_client?`, `logged_in_operator?`, `logged_in_visitor?`
- `show_cookie_banner?`, `cookie_banner_endpoint_url`
- `verification_viewer`, `verification_com_user`
- and others

### 3. rescue_from (hidden exception handling)

- `LoginCooldownError` (authentication/base)
- `ActionPolicy::Unauthorized` (authorization_audit, sign/error_responses)
- `ApplicationError` (sign/error_responses)
- `ActionController::InvalidCrossOriginRequest` (sign/error_responses)

### 4. alias_method (method name indirection)

- `alias_method :current_client, :current_resource`
- `alias_method :current_operator, :current_resource`
- `alias_method :current_visitor, :current_resource`
- `alias_method :authenticate_client!, :authenticate!`
- `alias_method :authenticate_operator!, :authenticate!`
- `alias_method :authenticate_visitor!, :authenticate!`

### 5. before_action / after_action (callbacks)

- `before_action :set_preferences_cookie` (preference/base)
- Many others

### 6. Layout/helper configuration

- `layout "sign/com/application"`
- `helper Sign::Com::ApplicationHelper`
- `protect_from_forgery`

## Refactoring Priority

| Priority | Reason                                    | Targets               |
| -------- | ----------------------------------------- | --------------------- |
| High     | Complex dependencies, large side effects  | #1, #2, #6, #7        |
| Medium   | Includes multiple before_action callbacks | #8, #9, #10, #11, #12 |
| Low      | Only a single helper_method               | #17-29                |

## Incremental Refactoring Plan

1. **Phase 1**: Create test cases for all concerns
2. **Phase 2**: Refactor high-priority concerns
   - Remove `included do` and include explicitly at the controller layer
3. **Phase 3**: Refactor medium-priority concerns
4. **Phase 4**: Refactor low-priority concerns

## Test Requirements

### Required test cases

1. **Behavior on include** - Verify that elements added through `included do` are available
   correctly
2. **Dependency tests** - Verify that behavior does not change based on include order
3. **Callback registration tests** - Verify that before_action/after_action callbacks run when
   required
4. **helper_method registration tests** - Verify that helper_method is registered correctly

### Existing test locations

- `test/controllers/concerns/auth/base_test.rb`
- `test/controllers/concerns/sign/error_responses_test.rb`
- `test/controllers/concerns/rate_limit_test.rb`
- etc.
