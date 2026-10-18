# frozen_string_literal: true

require "test_helper"

class PasskeyOptionsAnonymityInvariantTest < ActiveSupport::TestCase
  test "discoverable authentication options have no credential allow list" do
    config = Webauthn::RelyingPartyConfig.new(
      rp_id: "auth.umaxica.app",
      origin: "https://auth.umaxica.app",
    )

    options = Webauthn::AssertionVerifier.options_for(
      config: config,
      allow_ids: [],
      purpose: :direct_sign_in,
    )

    assert_empty options.allow_credentials
  end
end
