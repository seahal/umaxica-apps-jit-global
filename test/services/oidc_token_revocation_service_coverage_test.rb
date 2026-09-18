# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcTokenRevokerCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  Token =
    Struct.new(:oidc_client_id, :oidc_jti) do
      def has_attribute?(name)
        %i(oidc_jti oidc_client_id).include?(name.to_sym)
      end

      def revoke!(status: "failed", now: Time.current)
        @revoke_arguments = { status: status, now: now }
        @revoked = true
      end

      attr_reader :revoke_arguments

      def revoked?
        @revoked == true
      end

      def parent_token
        self
      end

      def with_lock
        yield
      end
    end

  test "rejects invalid client authentication" do
    service = ::OidcTokenRevoker.new(
      token: "token",
      client_id: "client-1",
      client_secret: "secret",
      host: "app.example.test",
    )

    OidcClientRegistry.stub(:authenticate, false) do
      result = service.call

      assert_not result.success?
      assert_equal "invalid_client", result.error
    end
  end

  test "rejects an authenticated client from the wrong surface realm" do
    service = ::OidcTokenRevoker.new(
      token: "token",
      client_id: "client-1",
      client_secret: "secret",
      expected_resource_type: "visitor",
      host: "com.example.test",
    )
    client = Struct.new(:resource_type).new("client")

    OidcClientRegistry.stub(:find, client) do
      OidcIssuer.stub(:resource_type_for_client, "client") do
        OidcClientRegistry.stub(:authenticate, true) do
          result = service.call

          assert_not result.success?
          assert_equal "invalid_client", result.error
        end
      end
    end
  end

  test "revokes refresh token when the digest matches" do
    token = Token.new("client-1", nil)
    service = ::OidcTokenRevoker.new(
      token: "refresh.public.verifier",
      client_id: "client-1",
      client_secret: "secret",
      host: "app.example.test",
    )

    OidcClientRegistry.stub(:authenticate, true) do
      ClientToken.stub(:parse_refresh_token, ["public", "verifier"]) do
        service.stub(:client_resource_type, "client") do
          service.stub(:find_rp_session_by_public_id, token) do
            token.define_singleton_method(:refresh_token_digest_matches?) { |verifier| verifier == "verifier" }

            result = service.call

            assert_predicate result, :success?
            assert_predicate token, :revoked?
          end
        end
      end
    end
  end

  test "revokes access token when refresh token parsing fails" do
    token = Token.new("client-1", "jti-1")
    service = ::OidcTokenRevoker.new(
      token: "access-token",
      client_id: "client-1",
      client_secret: "secret",
      host: "app.example.test",
    )

    client = Struct.new(:aud).new("aud-1")

    OidcClientRegistry.stub(:authenticate, true) do
      ClientToken.stub(:parse_refresh_token, nil) do
        OidcClientRegistry.stub(:find, client) do
          OidcClientRegistry.stub(:find!, client) do
            OidcIssuer.stub(:resource_type_for_client, "client") do
              OidcIssuer.stub(:for_client, "issuer") do
                OidcIssuer.stub(:jwt_issuer_id_for_client, "issuer-id") do
                  AuthenticationTokenService.stub(:decode_allow_expired, { "sid" => "sid-1", "jti" => "jti-1" }) do
                    service.stub(:find_rp_session_by_sid, token) do
                      result = service.call

                      assert_predicate result, :success?
                      assert_predicate token, :revoked?
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  test "accepts an access-token revocation request when its client is no longer registered" do
    service = ::OidcTokenRevoker.new(
      token: "access-token",
      client_id: "removed-client",
      client_secret: "secret",
      host: "app.example.test",
    )

    OidcClientRegistry.stub(:authenticate, true) do
      ClientToken.stub(:parse_refresh_token, nil) do
        OidcClientRegistry.stub(:find, nil) do
          result = service.call

          assert_predicate result, :success?
          assert_nil result.error
        end
      end
    end
  end

  test "refresh token revocation ignores tokens for another client" do
    token = Token.new("other-client", nil)
    service = ::OidcTokenRevoker.new(
      token: "refresh.public.verifier",
      client_id: "client-1",
      client_secret: "secret",
      host: "app.example.test",
    )

    OidcClientRegistry.stub(:authenticate, true) do
      ClientToken.stub(:parse_refresh_token, ["public", "verifier"]) do
        service.stub(:client_resource_type, "client") do
          service.stub(:find_rp_session_by_public_id, token) do
            result = service.call

            assert_predicate result, :success?
            assert_not_predicate token, :revoked?
          end
        end
      end
    end
  end

  test "access token revocation handles missing sid and jti mismatch" do
    token = Token.new("client-1", "expected-jti")
    service = ::OidcTokenRevoker.new(
      token: "access-token",
      client_id: "client-1",
      client_secret: "secret",
      host: "app.example.test",
    )

    client = Struct.new(:aud).new("aud-1")

    OidcClientRegistry.stub(:authenticate, true) do
      ClientToken.stub(:parse_refresh_token, nil) do
        OidcClientRegistry.stub(:find, client) do
          OidcClientRegistry.stub(:find!, client) do
            OidcIssuer.stub(:resource_type_for_client, "client") do
              OidcIssuer.stub(:for_client, "issuer") do
                OidcIssuer.stub(:jwt_issuer_id_for_client, "issuer-id") do
                  AuthenticationTokenService.stub(
                    :decode_allow_expired,
                    { "sid" => "sid-1", "jti" => "different-jti" },
                  ) do
                    service.stub(:find_rp_session_by_sid, token) do
                      result = service.call

                      assert_predicate result, :success?
                      assert_not_predicate token, :revoked?
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  test "RP Session lookup branches use the expected resource contexts" do
    service = ::OidcTokenRevoker.new(
      token: "token",
      client_id: "client-1",
      client_secret: "secret",
      host: "app.example.test",
    )

    assert_equal [AppTicketRecord, ClientRpSession], service.send(:rp_session_context_and_class, "client")
    assert_equal [OrgTicketRecord, OperatorRpSession], service.send(:rp_session_context_and_class, "operator")
    assert_equal [ComTicketRecord, VisitorRpSession], service.send(:rp_session_context_and_class, "visitor")
  end
end
