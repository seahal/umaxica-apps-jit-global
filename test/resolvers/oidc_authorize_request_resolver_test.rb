# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcAuthorizeRequestResolverTest < ActiveSupport::TestCase
  setup do
    @client = OidcClientRegistry.find!("core-app-jp")
    @resource = clients(:one)
    @params = {
      response_type: "code",
      client_id: @client.client_id,
      redirect_uri: @client.redirect_uris.first,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
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

    create_result = OidcAuthorizeRequestResolver.call(
      params: @params.merge(prompt: "create"), resource: @resource,
    )

    assert_equal "create", create_result.prompt
  end

  test "rejects prompt combinations and negative max_age" do
    { "none login" => "prompt must be a single value", "consent" => "prompt value is not supported" }
      .each do |prompt, message|
        error =
          assert_raises(OidcAuthorizeRequestResolver::UnsupportedPrompt) do
            OidcAuthorizeRequestResolver.call(params: @params.merge(prompt: prompt), resource: @resource)
          end
        assert_equal message, error.message
      end

    error =
      assert_raises(ArgumentError) do
        OidcAuthorizeRequestResolver.call(params: @params.merge(max_age: "-1"), resource: @resource)
      end
    assert_equal "max_age must be a non-negative integer", error.message
  end

  test "rejects create for the Org surface" do
    org_client = OidcClientRegistry.find!("core-org-jp")
    error =
      assert_raises(OidcAuthorizeRequestResolver::UnsupportedPrompt) do
        OidcAuthorizeRequestResolver.call(
          params: @params.merge(
            prompt: "create", client_id: org_client.client_id,
            redirect_uri: org_client.redirect_uris_by_realm.fetch("operator").first,
          ),
          resource: operators(:one), resource_type: "operator",
        )
      end

    assert_equal "prompt value is not supported", error.message
  end
end
