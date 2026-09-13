# Authorization Implementation Guide

## Overview

This application implements authorization with **Action Policy** through the `action_policy` gem. It
does not use Pundit.

Core rules:

- The authorization context is an **Actor** (`Actor::Context`). ApplicationController classes bind
  it with `authorize :actor, through: :current_actor`.
- Every policy inherits from `ApplicationPolicy < ActionPolicy::Base` and defaults to deny-all. An
  action is forbidden unless its predicate explicitly returns true.
- `ApplicationPolicy` provides ownership, role, JWT scope, and app/org/com surface helpers.

Related implementation:

- Base policy: `app/policies/application_policy.rb`
- Policies: `app/policies/`, including `ClientPolicy`, `OperatorPolicy`, and `VisitorPolicy`
- Context: `app/models/actor.rb` and `app/controllers/concerns/actor_support.rb`
- Failure handling: `app/controllers/concerns/authorization_audit.rb`

## Actor Authorization Context

`ApplicationPolicy` declares two contexts:

```ruby
class ApplicationPolicy < ActionPolicy::Base
  # Actor::Context is primary. The legacy `user` is derived from actor when omitted.
  authorize :actor, optional: true
  authorize :user, optional: true

  def user
    @user || actor_resource
  end
  # ...
end
```

Each surface ApplicationController supplies the actor, for example in
`app/controllers/core/app/application_controller.rb`:

```ruby
authorize :actor, through: :current_actor
```

`current_actor` returns `Actor.context`, which is based on `ActiveSupport::CurrentAttributes`, from
`app/controllers/concerns/actor_support.rb`. Within a policy:

- `actor` is the `Actor::Context`.
- `user` is the concrete Client, Operator, or Visitor derived from the actor, or nil when anonymous.
- `record` is the resource being authorized.

## ApplicationPolicy Helpers

`app/policies/application_policy.rb` provides these policy helpers:

| Method                                                                        | Meaning                                                                                                               |
| ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `actor` / `user`                                                              | Authorization context and derived concrete resource                                                                   |
| `record`                                                                      | Resource being authorized                                                                                             |
| `owner?`                                                                      | Whether `user` owns `record`, using Client `user_id`, Operator `staff_id`, Visitor `visitor_id`, or resource identity |
| `operator?` / `manager?` / `editor?` / `contributor?` / `viewer?`             | Organization-scoped role checks                                                                                       |
| `operator_or_manager?` / `can_edit?` / `can_view?` / `can_contribute?`        | Composite role checks                                                                                                 |
| `has_scope?(scope)`                                                           | JWT scope check based on the current token's `scp` claim                                                              |
| `domain_app?` / `domain_org?` / `domain_com?` / `domain_permitted?(*domains)` | Surface checks based on the JWT `aud` claim                                                                           |
| `current_token`                                                               | `Actor.authz.token_claims`                                                                                            |

The default `index?`, `show?`, `create?`, `update?`, and `destroy?` predicates all return false.
`alias_rule` maps `edit?` to `update?` and `new?` to `create?`.

## Implementing a Policy

Example from `app/policies/client_policy.rb`:

```ruby
class ClientPolicy < ApplicationPolicy
  def index?
    user.is_a?(Operator) && operator_or_manager?
  end

  def show?
    owner? || (user.is_a?(Operator) && operator_or_manager?)
  end

  def create?
    user.is_a?(Operator) && operator?
  end

  def update?
    owner? || (user.is_a?(Operator) && operator_or_manager?)
  end

  def destroy?
    (owner? && user.is_a?(Client)) || (user.is_a?(Operator) && operator?)
  end

  # Define list filtering with relation_scope.
  relation_scope do |relation|
    if user.is_a?(Operator) && operator_or_manager?
      relation.all
    elsif user.is_a?(Client)
      relation.where(id: user.id)
    else
      relation.none
    end
  end
end
```

Important points:

- Branch explicitly on the Client, Operator, or Visitor actor type.
- Check ownership explicitly with `owner?`.
- Define scopes with Action Policy's `relation_scope`, not a Pundit `Scope` class.

## Controller Usage

### Authorizing an Action

Call `authorize!(record, to: :action?)`. Because a `before_action` cannot pass the predicate symbol
directly, this application conventionally registers a named wrapper method:

```ruby
class Sign::App::Settings::SessionsController < ...
  before_action :authorize_sessions!, only: %i(index)

  private

  def authorize_sessions!
    authorize!(ClientToken, to: :index?)
  end
end
```

A concrete record may also be passed directly, such as `authorize!(current_client, to: :show?)`.

### Applying a Scope

Use `authorized_scope` to apply `relation_scope` to a collection. For example,
`app/controllers/sign/app/settings/passkeys_controller.rb` uses:

```ruby
@passkeys = authorized_scope(current_client.client_passkeys).order(created_at: :desc)
```

## Authorization Failure Behavior

Each surface ApplicationController catches authorization failures:

```ruby
rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
```

`handle_authorization_error` in `app/controllers/concerns/authorization_audit.rb`:

- Records an `authorization.failure` audit event and audit record. An audit-write error is isolated
  so it does not stop the application response.
- For HTML, sets the translated not-authorized message and calls
  `safe_redirect_back_or_to(root_path)`.
- For JSON, returns `{ error: "Unauthorized" }` with HTTP 403 Forbidden.

Authorization and **step-up authentication** are separate layers. Step-up uses
`Verification::Base#require_step_up!` and the `step_up` DSL in `Verification::StepUpGuard`; its
failures return a 302 redirect, 401, or 422. Those are distinct from an Action Policy 403.

## Testing

Unit-test policies under `test/policies/` with Action Policy's test support. Cover allowed and
denied cases, anonymous actors, another user, another staff member, and each relevant actor type.

```ruby
require "test_helper"

class ClientPolicyTest < ActiveSupport::TestCase
  test "operator manager can view the client list" do
    assert_predicate ClientPolicy.new(record, actor: operator_manager_context), :index?
  end

  test "anonymous actor cannot view the client list" do
    assert_not_predicate ClientPolicy.new(record, actor: anonymous_context), :index?
  end
end
```

See `test/policies/application_policy_actor_context_test.rb` for concrete context construction.

## Best Practices

1. **Default to deny:** `ApplicationPolicy` is an allowlist. Permit only necessary predicates.
2. **Authorize explicitly:** Controllers must call `authorize!` or `authorized_scope`.
3. **Name actor type and ownership:** Combine explicit `user.is_a?(...)` checks with `owner?`.
4. **Use Actor context:** Use `actor` and `user`, not controller instance variables.
5. **Test boundaries:** Cover allowed, denied, anonymous, and cross-boundary cases for each policy.

## Troubleshooting

### `ActionPolicy::Unauthorized` Is Raised

- The policy predicate for the action returned false. Check the policy, actor type, ownership, and
  role.
- If denial is expected, the 403 or redirect is correct. Otherwise, revise the predicate condition.

### The Policy Cannot Be Found

Check naming: model `Client` maps to `ClientPolicy` in `app/policies/client_policy.rb`. For
authorization without a record, pass a class such as `authorize!(SomeClass, to: :action?)`.

### Context Is Missing

Confirm that `set_current_actor` populated `current_actor`, which equals `Actor.context`, through
`app/controllers/concerns/actor_support.rb`. BareController classes intentionally bypass this
lifecycle.
