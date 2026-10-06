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

  test "does not require a session version on the resource" do
    resource = Object.new
    def resource.session_version
      raise "session_version is not an authority"
    end

    assert AuthenticationLogoutAllSessions.call(resource: resource)
  end
end
