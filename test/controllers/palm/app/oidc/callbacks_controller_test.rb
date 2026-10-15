# typed: false
# frozen_string_literal: true

require "test_helper"

module Palm
  module App
    module Oidc
      class CallbacksControllerTest < ActionDispatch::IntegrationTest
        HOST = ENV.fetch("PUBLIC_PALM_SERVICE_URL")
        BASE_HOST = ENV.fetch("PUBLIC_BASE_SERVICE_URL")

        setup do
          host! HOST
          https!
          @user = clients(:one)
          ClientIdentityState.ensure_defaults!
          ClientTokenStatus.ensure_defaults!
          ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
          ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::NOTHING)
          ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
        end

        test "callback rejects missing browser state before token exchange" do
          OidcRpTokenClient.stub(:call, ->(**) { flunk("callback must reject before code exchange") }) do
            get palm_app_oidc_callback_url, params: { code: "retired-code" }
          end

          assert_response :unprocessable_content
          assert_equal "no-store", response.headers["Cache-Control"]
          assert_nil cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
          assert_nil cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
        end

        test "native app callback paths do not route" do
          assert_raises(ActionController::RoutingError) do
            Rails.application.routes.recognize_path("https://#{HOST}/oauth/callback/ios", method: :get)
          end

          assert_raises(ActionController::RoutingError) do
            Rails.application.routes.recognize_path("https://#{HOST}/oauth/callback/android", method: :get)
          end
        end

        test "valid Palm browser callback verifies the real identity and opens its protected page" do
          identity = ClientIdentity.create!(
            issuer: OidcIssuer.for_resource_type("client"),
            subject: OidcSubject.for(@user, resource_type: "client"),
            audience: "base-app-ww",
            source_record_id: @user.id,
            status_id: ClientIdentityState::ACTIVE,
          )
          state, flow, authorization_params = start_palm_browser_flow
          client = OidcClientRegistry.find!("palm-app")
          authentication_event_at = 1.minute.ago
          root_token = ClientToken.create!(user: @user, authentication_event_at: authentication_event_at)
          authorization_code = OidcAuthorizationCodeIssuer.call(
            client: client,
            params: authorization_params.symbolize_keys,
            resource: @user,
            session_token: root_token,
            authentication_event_at: authentication_event_at,
          )
          expected_token_url = OidcIssuer.token_endpoint("client")
          exchange_result =
            OidcClientRegistry.stub(
              :authenticate_assertion,
              ->(client_id, assertion, token_url:) {
                client_id == "palm-app" && assertion.present? && token_url == expected_token_url
              },
            ) do
              OidcTokenExchangeCoordinator.call(
                grant_type: "authorization_code",
                code: authorization_code.code,
                redirect_uri: authorization_code.redirect_uri,
                client_id: "palm-app",
                client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
                client_assertion: "palm-browser-callback-test-assertion",
                token_endpoint_uri: expected_token_url,
                code_verifier: flow.fetch("code_verifier"),
                expected_resource_type: "client",
              )
            end

          assert_predicate exchange_result, :success?

          token_response = exchange_result.token_response
          id_token_payload, = JWT.decode(token_response.fetch(:id_token), nil, false)
          candidate_session = ClientRpSession.find_by!(public_id: id_token_payload.fetch("sid"))

          assert_predicate(
            OidcIdTokenVerifier.call(
              id_token: token_response.fetch(:id_token),
              client_id: "palm-app",
              resource_type: "client",
              expected_nonce: flow.fetch("nonce"),
              issuer: OidcIssuer.for_resource_type("client"),
              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
            ),
            :success?,
          )
          assert_predicate(
            OidcAccessTokenAuthenticator.call(
              access_token: token_response.fetch(:access_token),
              resource_type: "client",
              host: BASE_HOST,
              authorization_scheme: "Bearer",
            ),
            :success?,
          )
          token_result = OidcRpTokenClient::Result.new(
            success: true,
            token_response: token_response,
            error: nil,
          )
          userinfo_result = OidcRpUserInfoClient::Result.new(
            success: true,
            claims: { "sub" => OidcSubject.for(@user, resource_type: "client") },
            error: nil,
            dependency_failure: false,
          )

          OidcRpTokenClient.stub(
            :call,
            ->(**arguments) {
              assert_equal "palm-app", arguments.fetch(:client_id)
              assert_equal authorization_code.redirect_uri, arguments.fetch(:redirect_uri)
              assert_equal flow.fetch("code_verifier"), arguments.fetch(:code_verifier)
              token_result
            },
          ) do
            OidcRpUserInfoClient.stub(:call, userinfo_result) do
              get palm_app_oidc_callback_url,
                  params: {
                    code: authorization_code.code,
                    state: state,
                    iss: OidcIssuer.for_resource_type("client"),
                    client_id: "app-ios-rp",
                    redirect_uri: "umaxica://oidc/callback",
                  }
            end
          end

          assert_response :redirect
          assert_equal "/dashboard", URI.parse(response.location).path
          assert_equal token_response.fetch(:access_token), cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
          assert_equal token_response.fetch(:refresh_token), cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
          assert_predicate candidate_session.reload, :active?
          assert_predicate root_token.reload, :currently_usable?
          binding = ClientOidcIdentityBinding.find_by!(
            issuer: OidcIssuer.for_resource_type("client"),
            subject: OidcSubject.for(@user, resource_type: "client"),
            audience: "palm-app",
          )

          assert_equal identity.id, binding.client_identity_id

          get palm_app_dashboard_path(ri: "jp")

          assert_response :success
          assert_equal "palm/app/dashboards/show", inertia_component
          persisted_session = ClientRpSession.find_by!(public_id: candidate_session.public_id)

          assert_equal @user.id,
                       ClientToken.find(persisted_session.client_token_id).user_id

          OidcRpTokenClient.stub(:call, ->(**) { flunk("consumed callback must not exchange again") }) do
            get palm_app_oidc_callback_url, params: {
              code: authorization_code.code, state: state, iss: OidcIssuer.for_resource_type("client"),
            }
          end

          assert_response :unprocessable_content
          assert_equal token_response.fetch(:access_token), cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
          assert_equal token_response.fetch(:refresh_token), cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
          assert_predicate candidate_session.reload, :active?
          assert_predicate root_token.reload, :currently_usable?
        end

        private

        def start_palm_browser_flow
          with_palm_jump_signing do
            with_forgery_protection do
              get(palm_app_sign_show_path(ri: "jp"))
              authenticity_token = css_select('input[name="authenticity_token"]').first["value"]
              post(
                palm_app_sign_create_path(ri: "jp"),
                params: { authenticity_token: authenticity_token, pt: "/dashboard" },
                headers: {
                  "Origin" => "https://#{HOST}",
                  "Sec-Fetch-Site" => "same-origin",
                  "X-CSRF-Token" => authenticity_token,
                },
              )
            end

            assert_response :see_other
            jump_uri = URI.parse(response.location)
            jump_token = Rack::Utils.parse_nested_query(jump_uri.query).fetch("rt")
            jump_payload, = JWT.decode(jump_token, nil, false)
            authorization_uri = URI.parse(jump_payload.fetch("url"))
            authorization_params = Rack::Utils.parse_nested_query(authorization_uri.query)
            state = authorization_params.fetch("state")
            flow = session.fetch(OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY).fetch(state)

            [state, flow, authorization_params]
          end
        end

        def with_palm_jump_signing
          key_name = "JWT_PALM_APP_PRIVATE_KEY"
          kid_name = "JWT_PALM_APP_ACTIVE_KID"
          gateway_name = "PUBLIC_JUMP_GATEWAY_URL"
          original_key = ENV[key_name]
          original_kid = ENV[kid_name]
          original_gateway = ENV[gateway_name]
          ENV[key_name] = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
          ENV[kid_name] = "palm-callback-test"
          ENV[gateway_name] = "https://jump.umaxica.net"
          JitSecurityJwtRegistry.reload!
          yield
        ensure
          original_key.nil? ? ENV.delete(key_name) : ENV[key_name] = original_key
          original_kid.nil? ? ENV.delete(kid_name) : ENV[kid_name] = original_kid
          original_gateway.nil? ? ENV.delete(gateway_name) : ENV[gateway_name] = original_gateway
          JitSecurityJwtRegistry.reload!
        end

        def with_forgery_protection
          previous = ActionController::Base.allow_forgery_protection
          ActionController::Base.allow_forgery_protection = true
          yield
        ensure
          ActionController::Base.allow_forgery_protection = previous
        end
      end
    end
  end
end
