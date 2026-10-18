# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcRealmBindingTest < ActiveSupport::TestCase
  Client = Struct.new(:registered_token_endpoint_auth_method, keyword_init: true)

  test "a token endpoint realm mismatch is rejected before authorization-code consume" do
    store = Class.new do
      attr_reader :consumed

      def read(_code)
        {
          "state" => "issued",
          "resource_type" => "client",
          "client_id" => "rp",
          "redirect_uri" => "https://rp.example.test/callback",
        }
      end

      def consume!(**)
        @consumed = true

        flunk("realm mismatch must be rejected before code consumption")
      end
    end.new

    client = Client.new(registered_token_endpoint_auth_method: "none")
    result = nil

    OidcClientRegistry.stub(:find, client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: "code",
        redirect_uri: "https://rp.example.test/callback",
        client_id: "rp",
        expected_resource_type: "visitor",
        code_store: store,
      )
    end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
    assert_nil store.consumed
  end

  test "a token endpoint without a trusted realm is rejected before authorization-code consume" do
    store = Class.new do
      attr_reader :consumed

      def read(_code)
        { "resource_type" => "client" }
      end

      def consume!(**)
        @consumed = true

        flunk("a missing endpoint realm must be rejected before code consumption")
      end
    end.new

    client = Client.new(registered_token_endpoint_auth_method: "none")
    result = nil

    OidcClientRegistry.stub(:find, client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: "code",
        redirect_uri: "https://rp.example.test/callback",
        client_id: "rp",
        expected_resource_type: nil,
        code_store: store,
      )
    end

    assert_not result.success?
    assert_equal "invalid_request", result.error
    assert_nil store.consumed
  end
end
