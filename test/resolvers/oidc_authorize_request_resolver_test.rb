# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcAuthorizeRequestResolverTest < ActiveSupport::TestCase
  setup do
    @client = OidcClientRegistry.find!("core-next-rp")
    @resource = clients(:one)
    @params = {
      response_type: "code",
      client_id: @client.client_id,
      redirect_uri: @client.redirect_uris.first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
    }
  end

  test "normalizes supported prompt and max_age values" do
    result = OidcAuthorizeRequestResolver.call(
      params: @params.merge(prompt: "login", max_age: "300"),
      resource: @resource,
    )

    assert_equal "login", result.prompt
    assert_equal 300, result.max_age
  end

  test "rejects prompt combinations and negative max_age" do
    ["none login", "consent"].each do |prompt|
      error =
        assert_raises(ArgumentError) do
          OidcAuthorizeRequestResolver.call(params: @params.merge(prompt: prompt), resource: @resource)
        end
      assert_equal "prompt is not supported", error.message
    end

    error =
      assert_raises(ArgumentError) do
        OidcAuthorizeRequestResolver.call(params: @params.merge(max_age: "-1"), resource: @resource)
      end
    assert_equal "max_age must be a non-negative integer", error.message
  end
end
