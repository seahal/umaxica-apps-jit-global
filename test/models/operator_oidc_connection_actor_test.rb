# frozen_string_literal: true

require "test_helper"

class OperatorOidcConnectionActorTest < ActiveSupport::TestCase
  fixtures :operators

  test "OIDC connection resolves its operator as the actor" do
    operator = operators(:one)
    connection = OperatorOidcConnection.new(staff: operator)

    assert_same operator, connection.actor
  end
end
