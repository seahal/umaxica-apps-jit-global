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

  test "an invalid expected realm is never accepted as a match" do
    coordinator = OidcTokenExchangeCoordinator.new(
      grant_type: "authorization_code",
      client_id: "rp",
      expected_resource_type: "not-a-realm",
    )

    assert_not coordinator.send(:expected_realm_matches?, "client")
  end

  test "refresh lookup receives the controller-selected realm before any rotation" do
    captured = nil
    coordinator = OidcTokenExchangeCoordinator.new(
      grant_type: "refresh_token",
      refresh_token: "refresh-token",
      client_id: "rp",
      expected_resource_type: "visitor",
    )

    OidcRefreshTokenIssuer.stub(
      :resolve,
      ->(**arguments) {
        captured = arguments
        nil
      },
    ) do
      result = coordinator.send(:exchange_refresh_token!)

      assert_not result.success?
      assert_equal "invalid_grant", result.error
    end

    assert_equal "visitor", captured.fetch(:resource_type)
  end

  test "replay family revocation reads and writes the RP Session on the surface writer" do
    coordinator = OidcTokenExchangeCoordinator.new(
      grant_type: "authorization_code",
      client_id: "rp",
      redirect_uri: "https://rp.example.test/callback",
      code_verifier: "verifier",
      expected_resource_type: "client",
    )
    session = Object.new
    calls = []

    AppTicketRecord.stub(
      :connected_to,
      lambda { |role:, &block|
        calls << role
        block.call
      },
    ) do
      ClientRpSession.stub(:find_by, session) do
        RpSessionRevoker.stub(:call, ->(**) { }) do
          coordinator.stub(:replay_owner_matches?, true) do
            coordinator.send(
              :revoke_linked_family!,
              {
                "client_id" => "rp",
                "redirect_uri" => "https://rp.example.test/callback",
                "resource_type" => "client",
                "rp_session_ref" => "rp-session",
              },
            )
          end
        end
      end
    end

    assert_equal [:writing], calls
  end
end
