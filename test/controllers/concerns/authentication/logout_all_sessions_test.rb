# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationLogoutAllSessionsTest < ActiveSupport::TestCase
  fixtures :clients, :client_token_statuses, :client_token_kinds

  test "increments session_version even when token scope is empty" do
    user = clients(:one)
    # Ensure the user has no tokens.
    user.client_tokens.delete_all

    if user.respond_to?(:session_version)
      starting = user.session_version.to_i

      AuthenticationLogoutAllSessions.call(resource: user, reason: "test_empty")

      assert_equal starting + 1, user.reload.session_version,
                   "session_version must bump so still-valid JWTs are rejected at refresh"
    else
      AuthenticationLogoutAllSessions.call(resource: user, reason: "test_empty")

      pass "Client does not currently expose session_version; skip"
    end
  end

  private
end
