# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcRefreshTokenIssuerResultTest < ActiveSupport::TestCase
  test "exposes successful refresh results through named fields" do
    token = Object.new
    previous_token = Object.new
    result = OidcRefreshTokenIssuer::Result.new(
      success: true,
      token: token,
      refresh_token: "replacement-refresh-token",
      previous_token: previous_token,
      reason: nil,
      token_response: nil,
      access_expires_at: nil,
      refresh_expires_at: nil,
    )

    assert_predicate result, :success?
    assert_equal token, result[:token]
    assert_equal previous_token, result.fetch(:previous_token)
  end

  test "raises for a required refresh value that is absent from a failure result" do
    result = OidcRefreshTokenIssuer::Result.new(
      success: false,
      token: nil,
      refresh_token: nil,
      previous_token: nil,
      reason: :invalid_format,
      token_response: nil,
      access_expires_at: nil,
      refresh_expires_at: nil,
    )

    error = assert_raises(KeyError) { result.fetch(:refresh_token) }

    assert_match(/key not found/, error.message)
  end
end
