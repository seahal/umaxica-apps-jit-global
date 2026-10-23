# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationLogoutAllSessionsTest < ActiveSupport::TestCase
  test "returns true when no actor is supplied" do
    assert AuthenticationLogoutAllSessions.call(resource: nil)
  end

  test "returns true for an unsupported actor class" do
    assert AuthenticationLogoutAllSessions.call(resource: Object.new)
  end

  test "revokes real Root sessions without a session version authority" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    encoded = AuthenticationToken.encode(
      actor, host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), resource_type: "client",
             session_public_id: token.public_id,
    )

    assert_predicate encoded, :present?
    assert_predicate token, :currently_usable?
    assert AuthenticationLogoutAllSessions.call(resource: actor)
    assert_predicate token.reload, :revoked?
    assert_predicate token.device_session.reload, :revoked?
  end
end
