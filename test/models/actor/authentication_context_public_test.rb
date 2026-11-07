# frozen_string_literal: true

require "test_helper"

class Actor::AuthenticationContextPublicTest < ActiveSupport::TestCase
  test "Standby authentication context is derived from the signed claim and withholds step-up" do
    authentication = Actor::Authentication.new(
      login_public_id: "standby-context-session",
      access_claims: { "authn_ctx" => "standby" },
      actor_type: :operator,
    )

    context = authentication.authentication_context

    assert_predicate context, :standby?
    assert_not context.step_up_permitted?
  end

  test "unknown authentication context claim does not become Normal" do
    authentication = Actor::Authentication.new(
      login_public_id: "unknown-context-session",
      access_claims: { "authn_ctx" => "unrecognized" },
      actor_type: :operator,
    )

    context = authentication.authentication_context

    assert_not context.normal?
    assert_not context.step_up_permitted?
  end
end
