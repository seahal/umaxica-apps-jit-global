# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageThresholdOidcEdgesTest < ActiveSupport::TestCase
  def service(**attrs)
    defaults = { grant_type: "authorization_code", code: "code", redirect_uri: "https://client/cb", client_id: "client", client_secret: nil, code_verifier: "verifier", client_assertion_type: nil, client_assertion: nil, dpop_proof: nil, token_endpoint_uri: nil, expected_resource_type: "client" }
    OidcTokenExchangeCoordinator.new(**defaults.merge(attrs))
  end

  test "public token exchange maps missing and atomic consume outcomes" do
    client = Struct.new(:registered_token_endpoint_auth_method, :allowed_scopes).new("none", %w(openid profile))
    payload = {
      "state" => "issued",
      "redirect_uri" => "https://client/cb",
      "client_id" => "client",
      "resource_type" => "client",
      "scope" => "openid",
      "auth_time" => Time.current.iso8601,
      "issued_at" => Time.current.iso8601,
      "code_challenge" => "verifier",
      "code_challenge_method" => "S256",
      "subject" => OidcSubject.for(clients(:one), resource_type: "client"),
      "base_session_ref" => client_tokens(:one).public_id,
    }

    OidcClientRegistry.stub(:find, client) do
      OidcClientRegistry.stub(:valid_redirect_uri?, true) do
        OidcClientRegistry.stub(:find!, client) do
          OidcPkce.stub(:verify, true) do
            missing_code = service(code: nil).call

            assert_equal "invalid_grant", missing_code.error

            missing_store = Object.new
            missing_store.define_singleton_method(:read) { |_| nil }
            missing_record = service(code_store: missing_store).call

            assert_equal "invalid_grant", missing_record.error

            {
              missing: ["invalid_grant", "Authorization code not found"],
              expired: ["invalid_grant", "Authorization code expired"],
              replay: ["invalid_grant", "Authorization code already consumed"],
              mismatch: ["invalid_grant", "Authorization code mismatch"],
              corrupt: ["server_error", "authorization code consume failed"],
            }.each do |status, (error, description)|
              store = Object.new
              store.define_singleton_method(:read) { |_| payload }
              store.define_singleton_method(:consume!) do |**|
                Valkey::AuthState::AuthorizationCodeStore::ConsumeResult.new(
                  status: status,
                  payload: payload,
                )
              end
              store.define_singleton_method(:mark_replay!) do |**|
                Valkey::AuthState::AuthorizationCodeStore::ConsumeResult.new(status: :marked, payload: payload)
              end

              result = service(code_store: store).call

              assert_equal error, result.error, status
              assert_equal description, result.error_description, status
            end
          end
        end
      end
    end
  end

  test "public refresh grant rejects missing credentials and unsafe session state" do
    client = Struct.new(:registered_token_endpoint_auth_method).new("none")
    OidcClientRegistry.stub(:find, client) do
      missing = service(
        grant_type: "refresh_token",
        code: nil,
        refresh_token: nil,
        expected_resource_type: "client",
      ).call

      assert_equal "invalid_grant", missing.error
      assert_equal "refresh_token is required", missing.error_description
    end
  end
end
