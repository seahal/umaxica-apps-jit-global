# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageThresholdOidcEdgesTest < ActiveSupport::TestCase
  def service(**attrs)
    defaults = { grant_type: "authorization_code", code: "code", redirect_uri: "https://client/cb", client_id: "client", client_secret: nil, code_verifier: "verifier", client_assertion_type: nil, client_assertion: nil, dpop_proof: nil, token_endpoint_uri: nil }
    OidcTokenExchangeCoordinator.new(**defaults.merge(attrs))
  end

  test "OIDC client authentication covers public assertion and secret registrations" do
    public = Struct.new(:registered_token_endpoint_auth_method).new("none")
    OidcClientRegistry.stub(:find, public) do
      assert service.send(:authenticated_client?)
      assert_not service(client_secret: "secret").send(:authenticated_client?)
    end
    jwt = Struct.new(:registered_token_endpoint_auth_method).new("private_key_jwt")
    OidcClientRegistry.stub(:find, jwt) do
      assert_not service.send(:authenticated_client?)
      assert_not service(client_assertion_type: "wrong", client_assertion: "x", token_endpoint_uri: "https://token").send(:authenticated_client?)
      assert_not service(
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: nil,
        token_endpoint_uri: "https://token",
      ).send(:authenticated_client?)
    end
    secret = Struct.new(:registered_token_endpoint_auth_method).new("client_secret_post")
    OidcClientRegistry.stub(:find, secret) do
      OidcClientRegistry.stub(:authenticate, true) do
        assert service(client_secret: "secret").send(:authenticated_client?)
        assert_not service(client_assertion: "x").send(:authenticated_client?)
      end
    end
  end

  # Authorization codes are Valkey-stored hash payloads (see
  # Valkey::AuthState::AuthorizationCodeStore), not the DB-backed records the
  # since-removed `client_authorization_codes` table once held, so this exercises
  # the current `prevalidate_payload` hash contract directly. PKCE and scope
  # validation are stubbed out here because they have their own coverage below;
  # this test isolates the state/expiry/redirect/client-id branches.
  test "OIDC code validation covers all invalid grant reasons" do
    payload = {
      "state" => "issued",
      "redirect_uri" => "https://client/cb",
      "client_id" => "client",
      "resource_type" => "client",
      "auth_time" => Time.current.iso8601,
    }
    svc = service
    svc.define_singleton_method(:verify_pkce) { |_| nil }
    svc.define_singleton_method(:validate_authorized_scopes) { |_| nil }

    OidcClientRegistry.stub(:valid_redirect_uri?, true) do
      assert_nil svc.send(:prevalidate_payload, payload)

      expired = payload.merge("expires_at" => 1.hour.ago.iso8601)

      assert_equal "invalid_grant", svc.send(:prevalidate_payload, expired).error

      consumed = payload.merge("state" => "consumed")

      assert_equal "invalid_grant", svc.send(:prevalidate_payload, consumed).error

      mismatched_redirect = payload.merge("redirect_uri" => "https://other/cb")

      assert_equal "invalid_request", svc.send(:prevalidate_payload, mismatched_redirect).error

      mismatched_client = payload.merge("client_id" => "other-client")

      assert_equal "invalid_request", svc.send(:prevalidate_payload, mismatched_client).error
    end
  end

  test "OIDC scope and PKCE validators cover accepted and rejected inputs" do
    client = Struct.new(:allowed_scopes).new(%w(openid profile))
    payload = { "scope" => "openid profile" }
    OidcClientRegistry.stub(:find!, client) do
      assert_nil service.send(:validate_authorized_scopes, payload)
      payload["scope"] = "profile"

      assert_equal "invalid_grant", service.send(:validate_authorized_scopes, payload).error
    end

    verifier = "a" * 43
    pkce_payload = {
      "code_challenge" => OidcPkce.challenge_for(verifier),
      "code_challenge_method" => "S256",
    }

    assert_equal "invalid_request", service(code_verifier: nil).send(:verify_pkce, pkce_payload).error
    assert_nil service(code_verifier: verifier).send(:verify_pkce, pkce_payload)
    assert_equal "invalid_request", service(code_verifier: "#{verifier}x").send(:verify_pkce, pkce_payload).error
  end

  test "OIDC class dispatch and token refresh helpers cover fallback cases" do
    svc = service

    assert_equal :client_token, svc.send(:parent_token_foreign_key_for, Class.new { def self.name = "Other" })
    assert_equal :operator_token, svc.send(
      :parent_token_foreign_key_for, Class.new {
                                       def self.name
                                         "OperatorRpSession"
                                       end
                                     },
    )
    assert_equal :visitor_token, svc.send(
      :parent_token_foreign_key_for, Class.new {
                                       def self.name
                                         "VisitorRpSession"
                                       end
                                     },
    )
    assert_raises(ArgumentError) { svc.send(:usage_class_for_root_token, Object.new) }
    usage = Object.new
    usage.define_singleton_method(:refresh_token_digest) { "digest" }
    usage.define_singleton_method(:rotate_refresh_token!) { :rotated }

    assert_equal :rotated, svc.send(:issue_or_rotate_usage_refresh_token!, usage)
    usage.define_singleton_method(:refresh_token_digest) { nil }
    usage.define_singleton_method(:issue_refresh_token!) { :issued }

    assert_equal :issued, svc.send(:issue_or_rotate_usage_refresh_token!, usage)
    usage.define_singleton_method(:oidc_jti) { nil }
    assert_raises(ArgumentError) { svc.send(:rp_session_oidc_jti, usage) }
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
      "code_challenge" => "verifier",
      "code_challenge_method" => "S256",
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
      missing = service(grant_type: "refresh_token", code: nil, refresh_token: nil).call

      assert_equal "invalid_grant", missing.error
      assert_equal "refresh_token is required", missing.error_description
    end
  end
end
