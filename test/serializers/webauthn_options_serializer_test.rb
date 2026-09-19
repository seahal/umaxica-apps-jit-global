# frozen_string_literal: true

require "test_helper"

class WebauthnOptionsSerializerTest < ActiveSupport::TestCase
  test "normalizes hash user ids and snake case credential lists" do
    options = {
      challenge: "challenge",
      user: { id: "user-id" },
      allow_credentials: [{ id: "credential-id", type: "public-key" }],
    }

    serialized = Webauthn::OptionsSerializer.as_json(options)

    assert_equal Base64.urlsafe_encode64("user-id", padding: false), serialized.dig("user", "id")
    assert_equal "credential-id", serialized.dig("allow_credentials", 0, "id")
    assert_equal "public-key", serialized.dig("allow_credentials", 0, "type")
  end
end
