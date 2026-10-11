# typed: false
# frozen_string_literal: true

require "test_helper"

module OmniAuth
  module Strategies
    class UmaxicaEntraTest < ActiveSupport::TestCase
      # Fixed test values. The strategy reads tenant and client from
      # ExternalAuthentication::ProviderRegistry, which is stubbed here so the
      # suite never depends on the deployment's real credential values.
      TENANT_ID = "11111111-2222-3333-4444-555555555555"
      CLIENT_ID = "22222222-3333-4444-5555-666666666666"
      OBJECT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

      test "request phase configures tenant-fixed endpoints from configuration" do
        strategy = build_strategy(path: "/social/entra", params: {})

        with_configured_tenant do
          strategy.stub(:redirect, nil) { strategy.request_phase }
        end

        assert_equal "https://login.microsoftonline.com/#{TENANT_ID}/v2.0", strategy.options.issuer
        assert_equal CLIENT_ID, strategy.options.client_options.identifier
        assert_equal "/#{TENANT_ID}/oauth2/v2.0/authorize", strategy.options.client_options.authorization_endpoint
        assert_equal "/#{TENANT_ID}/oauth2/v2.0/token", strategy.options.client_options.token_endpoint
        assert_not strategy.options.discovery
      end

      test "request phase fails closed when the provider is unavailable" do
        strategy = build_strategy(path: "/social/entra", params: {})

        strategy.stub(:entra_start_available?, false) do
          strategy.request_phase
        end

        assert_equal :provider_unavailable, strategy.env["omniauth.error.type"]
      end

      test "authorization URL never uses common/organizations/consumers and requests only openid profile" do
        strategy = build_strategy(path: "/social/entra", params: {})
        redirect_target = nil

        with_configured_tenant do
          strategy.stub(:redirect, ->(uri) { redirect_target = uri }) { strategy.request_phase }
        end

        uri = URI.parse(redirect_target)
        query = Rack::Utils.parse_nested_query(uri.query)

        assert_equal "login.microsoftonline.com", uri.host
        assert_equal "/#{TENANT_ID}/oauth2/v2.0/authorize", uri.path
        assert_not_includes uri.to_s, "common"
        assert_not_includes uri.to_s, "organizations"
        assert_not_includes uri.to_s, "consumers"
        assert_equal "openid profile", query.fetch("scope")
        assert_equal "S256", query.fetch("code_challenge_method")
        assert_predicate query.fetch("code_challenge"), :present?
        assert_predicate query.fetch("state"), :present?
        assert_predicate query.fetch("nonce"), :present?
      end

      test "access_token authenticates with client_secret_post and consumes the PKCE verifier once" do
        strategy = build_strategy(
          path: "/social/entra/callback",
          params: {},
          session: {
            "omniauth.pkce.verifier" => "pkce-verifier-value",
            "omniauth.nonce" => "expected-nonce",
          },
        )

        captured = nil
        fake_client = Object.new
        fake_client.define_singleton_method(:access_token!) do |**kwargs|
          captured = kwargs
          OpenStruct.new(id_token: "fake-id-token")
        end
        strategy.instance_variable_set(:@client, fake_client)

        verified_result = ExternalSignIn::NormalizedAuthResult.new(
          tenant_id: TENANT_ID,
          entra_object_id: OBJECT_ID,
          evidence_issuer: "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
          evidence_subject: "pairwise-subject",
        )
        verifier_double = Minitest::Mock.new
        verifier_double.expect(:call, verified_result)

        with_configured_tenant do
          ExternalSignIn::Providers::EntraId.stub(
            :new, ->(**kwargs) {
                    assert_equal "fake-id-token", kwargs.fetch(:id_token)
                    assert_equal "expected-nonce", kwargs.fetch(:expected_nonce)
                    assert_equal TENANT_ID, kwargs.fetch(:expected_tenant_id)
                    assert_equal CLIENT_ID, kwargs.fetch(:client_id)
                    verifier_double
                  },
          ) do
            strategy.access_token
          end
        end

        verifier_double.verify

        assert_equal :client_secret_post, captured.fetch(:client_auth_method)
        assert_equal "pkce-verifier-value", captured.fetch(:code_verifier)
        assert_nil strategy.send(:session)["omniauth.pkce.verifier"]
        # No certificate assertion is sent: client authentication is the shared
        # secret carried in the client options.
        assert_not captured.key?(:client_assertion)
        assert_not captured.key?(:client_assertion_type)
      end

      test "the AuthHash carries only verified claims and no raw tokens" do
        strategy = build_strategy(path: "/social/entra/callback", params: {}, session: {})
        strategy.instance_variable_set(
          :@verified_entra_result,
          ExternalSignIn::NormalizedAuthResult.new(
            tenant_id: TENANT_ID,
            entra_object_id: OBJECT_ID,
            evidence_issuer: "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
            evidence_subject: "pairwise-subject",
          ),
        )

        assert_equal "#{TENANT_ID}:#{OBJECT_ID}", strategy.uid
        assert_equal({}, strategy.info)
        assert_equal({}, strategy.credentials)
        assert_equal(
          {
            "tid" => TENANT_ID,
            "oid" => OBJECT_ID,
            "iss" => "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
            "sub" => "pairwise-subject",
          },
          strategy.extra.fetch(:raw_info),
        )
      end

      test "access_token fails closed when the PKCE verifier is missing" do
        strategy = build_strategy(path: "/social/entra/callback", params: {}, session: {})

        error = assert_raises(OmniAuth::Strategies::UmaxicaEntra::Error) { strategy.access_token }

        assert_equal :pkce_verifier_missing, error.reason
      end

      test "verify_id_token! raises instead of silently continuing on a missing id_token" do
        strategy = build_strategy(path: "/social/entra/callback", params: {}, session: {})

        error =
          strategy.stub(:stored_nonce, "expected-nonce") do
            assert_raises(OmniAuth::Strategies::UmaxicaEntra::Error) { strategy.verify_id_token!(nil) }
          end

        assert_equal :missing_id_token, error.reason
      end

      test "callback_phase converts a nested Error into fail! at the top level" do
        strategy = build_strategy(
          path: "/social/entra/callback",
          params: { "state" => "matching-state", "code" => "authorization-code" },
          session: { "omniauth.state" => "matching-state" },
        )

        with_configured_tenant do
          strategy.stub(
            :access_token, -> {
                             raise OmniAuth::Strategies::UmaxicaEntra::Error, :pkce_verifier_missing
                           },
          ) do
            strategy.callback_phase
          end
        end

        assert_equal :pkce_verifier_missing, strategy.env["omniauth.error.type"]
      end

      private

      def with_configured_tenant(&)
        ExternalAuthentication::ProviderRegistry.stub(:tenant_id, TENANT_ID) do
          ExternalAuthentication::ProviderRegistry.stub(:audience, CLIENT_ID) do
            ExternalAuthentication::ProviderRegistry.stub(
              :issuer_for, "https://login.microsoftonline.com/#{TENANT_ID}/v2.0", &
            )
          end
        end
      end

      def build_strategy(path:, params:, session: {})
        env = Rack::MockRequest.env_for(path, params: params, method: "GET")
        env["rack.session"] = session
        strategy = OmniAuth::Strategies::UmaxicaEntra.new(->(inner_env) { [404, {}, [inner_env.inspect]] })
        strategy.instance_variable_set(:@env, env)
        strategy
      end
    end
  end
end
