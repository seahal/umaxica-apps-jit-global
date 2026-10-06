# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationLogoutAllSessionsTest < ActiveSupport::TestCase
  fixtures :clients, :client_token_statuses, :client_token_kinds

  test "bulk logout succeeds even when the actor has no tokens" do
    user = clients(:one)
    # Ensure the user has no tokens.
    user.client_tokens.delete_all

    assert AuthenticationLogoutAllSessions.call(resource: user, reason: "test_empty")
  end

  private
end
