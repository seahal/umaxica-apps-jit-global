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

  test "propagates a token revocation failure instead of reporting batch success" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    AuthenticationLogoutCurrentSession.stub(
      :call,
      ->(**) { raise ActiveRecord::StatementInvalid, "writer unavailable" },
    ) do
      assert_raises(ActiveRecord::StatementInvalid) do
        AuthenticationLogoutAllSessions.call(resource: user, reason: "test_failure")
      end
    end

    assert_predicate token.reload, :currently_usable?
  end

  private
end
