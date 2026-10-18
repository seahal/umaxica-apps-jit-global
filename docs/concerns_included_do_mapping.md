# Concern `included do` mapping table

This document is located in `included do` in `app/controllers/concerns/` Document what side effects
the block has.

## mapping table

| #   | File                                       | Contents of included do                                                                                                                                                                                                                                                | Depends on                             |
| --- | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| 1   | `authentication/base.rb:861-872`           | `include ::Sign::ErrorResponses`<br>`include ::SessionLimitGate`<br>`rescue_from LoginCooldownError`<br>`helper_method :current_account, :current_session_public_id`                                                                                                   | Sign::ErrorResponses, SessionLimitGate |
| 2   | `authentication/user.rb:17-23`             | `helper_method :current_user, :logged_in?, :active_user?, :logged_in_user?`<br>`alias_method :current_user, :current_resource`<br>`alias_method :authenticate_user!, :authenticate!`<br>`alias_method :logged_in_user?, :logged_in?`<br>`include ::AuthorizationAudit` | AuthorizationAudit                     |
| 3   | `authentication/staff.rb:17-23`            | Same as above (staff version)                                                                                                                                                                                                                                          | AuthorizationAudit                     |
| 4   | `authentication/customer.rb:17-23`         | Same as above (customer version)                                                                                                                                                                                                                                       | AuthorizationAudit                     |
| 5   | `authentication/viewer.rb:10-13`           | `helper_method :current_viewer`                                                                                                                                                                                                                                        | -                                      |
| 6   | `authorization_audit.rb:9-16`              | `include Common::Redirect`<br>`rescue_from ActionPolicy::Unauthorized`                                                                                                                                                                                                 | Common::Redirect                       |
| 7   | `sign/error_responses.rb:16-25`            | `include Common::Redirect`<br>`rescue_from ActionPolicy::Unauthorized`<br>`rescue_from ApplicationError`<br>`rescue_from ActionController::InvalidCrossOriginRequest`                                                                                                  | Common::Redirect                       |
| 9   | `sign/org_verification_base.rb:18-22`      | `helper_method :verification_viewer`<br>`before_action :load_verification_viewer`<br>`before_action :verify_verification_viewer`                                                                                                                                       | -                                      |
| 10  | `sign/app_verification_base.rb:23-28`      | Same as above (app version)                                                                                                                                                                                                                                            | -                                      |
| 11  | `sign/com_verification_base.rb:152-157`    | `helper_method :verification_com_user`<br>`before_action :load_verification_com_user`                                                                                                                                                                                  | -                                      |
| 12  | `sign/email_registrable.rb:32-40`          | `helper_method :email_registrable?`<br>`before_action :load_registration_session`<br>`before_action :verify_registration_session`                                                                                                                                      | -                                      |
| 13  | `sign/email_registration_flow.rb:11-17`    | `helper_method :email_registration_url`<br>`before_action :load_registration_flow`<br>`before_action :verify_registration_flow`                                                                                                                                        | -                                      |
| 14  | `sign/telephone_registrable.rb:8-12`       | `helper_method :telephone_registrable?`<br>`before_action :load_telephone_registration_session`                                                                                                                                                                        | -                                      |
| 15  | `sign/staff_telephone_registrable.rb:8-12` | Same as above (staff version)                                                                                                                                                                                                                                          | -                                      |
| 16  | `sign/edge_v0_json_api.rb:8-13`            | `helper_method :edge_v0_json_api?`<br>`before_action :set_edge_v0_json_api_format`                                                                                                                                                                                     | -                                      |
| 17  | `preference/base.rb:415-418`               | `helper_method :show_cookie_banner?, :cookie_banner_endpoint_url`<br>`before_action :set_preferences_cookie`                                                                                                                                                           | -                                      |
| 18  | `preference/core.rb:8-12`                  | `helper_method :preference_scope`<br>`before_action :load_preference_from_token`                                                                                                                                                                                       | -                                      |
| 19  | `preference/edge.rb:8-13`                  | `helper_method :preference_editable?`<br>`before_action :verify_preference_editable`                                                                                                                                                                                   | -                                      |
| 20  | `preference/web_cookie_actions.rb:8-12`    | `helper_method :web_preference_cookie`<br>`before_action :load_web_preference`                                                                                                                                                                                         | -                                      |
| 21  | `preference/web_theme_actions.rb:8-11`     | `helper_method :web_theme`<br>`before_action :load_web_theme`                                                                                                                                                                                                          | -                                      |
| 22  | `preference/regional.rb:8-12`              | `helper_method :regional_preference`<br>`before_action :load_regional_preference`                                                                                                                                                                                      | -                                      |
| 23  | `preference/global.rb:18-22`               | `helper_method :global_preference`<br>`before_action :load_global_preference`                                                                                                                                                                                          | -                                      |
| 24  | `preference/adoption.rb:8-11`              | `before_action :adopt_preference_if_logged_in`                                                                                                                                                                                                                         | -                                      |
| 25  | `actor_support.rb`                         | None. `set_current_context` / `set_current_actor` / `set_current_observability` / `_reset_current_state` is called from the explicit callback on the controller side.                                                                                                  | -                                      |
| 26  | `minimum_response_budget.rb:7-9`           | `after_action :enforce_minimum_response_budget`                                                                                                                                                                                                                        | -                                      |
| 27  | `social_auth.rb:31-36`                     | `helper_method :social_auth_providers`<br>`before_action :load_social_auth_config`                                                                                                                                                                                     | -                                      |
| 28  | `social_callback_guard.rb:29-32`           | `before_action :verify_social_callback_state`                                                                                                                                                                                                                          | -                                      |
| 29  | `oidc/callback.rb:8-11`                    | `helper_method :oidcCallback`<br>`before_action :verify_oidc_callback`                                                                                                                                                                                                 | -                                      |

## Classification of side effects

### 1. include other modules (implicit dependency)

- `include Common::Redirect` (authorization_audit, sign/error_responses)
- `include Sign::ErrorResponses` (authentication/base)
- `include SessionLimitGate` (authentication/base)
- `include AuthorizationAudit` (authentication/user/staff/customer)

### 2. helper_method registration (availability from view)

- `current_account`, `current_user`, `current_staff`, `current_viewer`
- `logged_in?`, `logged_in_user?`, `active_user?`
- `show_cookie_banner?`, `cookie_banner_endpoint_url`
- `verification_viewer`, `verification_com_user`
- etc. etc.

### 3. rescue_from (hidden exception handling)

- `LoginCooldownError` (authentication/base)
- `ActionPolicy::Unauthorized` (authorization_audit, sign/error_responses)
- `ApplicationError` (sign/error_responses)
- `ActionController::InvalidCrossOriginRequest` (sign/error_responses)

### 4. alias_method (hidden method name)

- `alias_method :current_user, :current_resource`
- `alias_method :authenticate_user!, :authenticate!`

### 5. before_action / after_action (callback)

- `before_action :set_preferences_cookie` (preference/base)
- many

### 6. Layout/helper settings

- `layout "sign/com/application"`
- `helper Sign::Com::ApplicationHelper`
- `protect_from_forgery`

## Refactoring priority

| Priority | Reason                                   | Target                |
| -------- | ---------------------------------------- | --------------------- |
| High     | Complex dependencies, large side effects | #1, #2, #6, #7        |
| Medium   | Contains multiple before_actions         | #8, #9, #10, #11, #12 |
| Low      | Single helper_method only                | #17-29                |

## Incremental refactoring plan

1. **Phase 1**: Test case creation (for all concerns)
2. **Phase 2**: Refactoring of high priority concerns
   - Remove `included do` and include it explicitly in controller layer
3. **Phase 3**: Refactoring of medium priority concerns
4. **Phase 4**: Refactoring of low priority concerns

## Test requirements

### Required test case

1. **Operation verification when including** - The element added with `included do` is correctly
   available.
2. **Dependency test** - There is no change in behavior depending on the order of inclusion.
3. **Callback registration test** - Invoke when before_action/after_action is required
4. **helper_method registration test** - Ensure that helper_method is registered correctly

### Location of existing tests

- `test/controllers/concerns/auth/base_test.rb`
- `test/controllers/concerns/sign/error_responses_test.rb`
- `test/controllers/concerns/rate_limit_test.rb`
- etc.
