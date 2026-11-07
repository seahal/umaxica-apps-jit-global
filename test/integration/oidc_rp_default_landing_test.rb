# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcRpDefaultLandingTest < ActionDispatch::IntegrationTest
  RP_CASES = [
    { client_id: "base-app-ww", host: "PUBLIC_BASE_SERVICE_URL", resource_type: "client", landing: "/dashboard" },
    { client_id: "base-org-ww", host: "PUBLIC_BASE_STAFF_URL", resource_type: "operator", landing: "/dashboard" },
    { client_id: "core-app-jp", host: "PUBLIC_CORE_SERVICE_URL", resource_type: "client", landing: "/" },
    { client_id: "core-org-jp", host: "PUBLIC_CORE_STAFF_URL", resource_type: "operator", landing: "/" },
    { client_id: "palm-app-jp", host: "PUBLIC_PALM_SERVICE_URL", resource_type: "client", landing: "/dashboard" },
    { client_id: "warp-app-jp", host: "PUBLIC_WARP_SERVICE_URL", resource_type: "client", landing: "/dashboard" },
    { client_id: "warp-org-jp", host: "PUBLIC_WARP_STAFF_URL", resource_type: "operator", landing: "/dashboard" },
  ].freeze

  TARGET_CASES = [
    { label: "without a target", entry_target: nil, target: nil, landing: nil },
    { label: "with a valid target", entry_target: "/after", target: "/after", landing: "/after" },
    {
      label: "with an invalid external target", entry_target: nil, target: "//attacker.example", landing: nil,
    },
  ].freeze

  test "public OIDC callbacks honor a target or the explicit RP landing" do
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.ensure_defaults!
    ClientTokenBindingMethod.ensure_defaults!
    ClientTokenDbscStatus.ensure_defaults!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.ensure_defaults!
    OperatorStatus.ensure_defaults!

    RP_CASES.each do |rp|
      TARGET_CASES.each do |target_case|
        reset!
        host = ENV.fetch(rp.fetch(:host))
        host! host
        https!
        get "/sign", params: { ri: "jp", target_link_uri: target_case.fetch(:entry_target) }

        assert_response :success, "#{rp.fetch(:client_id)} Sign entry establishes its browser session"

        oidc_client = OidcClientRegistry.find!(rp.fetch(:client_id))
        resource_type = rp.fetch(:resource_type)
        form = response.parsed_body.at_css("form")
        fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        post form["action"], params: fields, headers: {
          "Origin" => "https://#{host}",
          "Sec-Fetch-Site" => "same-origin",
        }

        assert_response :see_other, "#{rp.fetch(:client_id)} sign POST starts an OIDC flow"
        jti, pending_flow = session.fetch(OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY).first
        state, = OidcStateJwt.issue(
          client_id: oidc_client.client_id,
          target_link_uri: target_case.fetch(:target),
          jti: jti,
        )
        resource =
          if resource_type == "client"
            Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
          else
            Operator.create!(
              security_mode_id: SecurityModeConfigurable::ADVANCED,
              status_id: OperatorStatus::ACTIVE,
            )
          end
        authentication_time = 1.minute.ago
        root_token =
          if resource_type == "client"
            ClientToken.create!(
              authentication_epoch: 0,
              user: resource,
              user_token_kind_id: ClientTokenKind::BROWSER_WEB,
              user_token_status_id: ClientTokenStatus::ACTIVE,
              user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
              user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
              authentication_event_at: authentication_time,
            )
          else
            OperatorToken.create!(
              authentication_epoch: 0,
              staff: resource,
              staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
              staff_token_status_id: OperatorTokenStatus::ACTIVE,
              authentication_event_at: authentication_time,
            )
          end
        grant =
          if resource_type == "client"
            OpAppGrant.create!(
              authentication_epoch: 0,
              client_token: root_token,
              oidc_client_id: oidc_client.client_id,
              oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid,
              oidc_auth_time: authentication_time,
              refresh_token_expires_at: 1.hour.from_now,
            )
          else
            OpOrgGrant.create!(
              authentication_epoch: 0,
              operator_token: root_token,
              oidc_client_id: oidc_client.client_id,
              oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid,
              oidc_auth_time: authentication_time,
              refresh_token_expires_at: 1.hour.from_now,
            )
          end

        nonce = pending_flow.fetch("nonce")
        access_token = AuthenticationTokenService.encode(
          resource,
          host: OidcIssuer.host_for_client(oidc_client),
          resource_type: resource_type,
          session_public_id: root_token.public_id,
          base_session_public_id: root_token.public_id,
          oidc_sid: grant.public_id,
          oidc_jti: grant.oidc_jti,
          expires_at: 5.minutes.from_now,
          scopes: %w(openid profile),
          issuer: OidcIssuer.for_client(oidc_client),
          audiences: [oidc_client.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(oidc_client),
          subject: OidcSubject.for(resource, resource_type: resource_type),
          client_id: oidc_client.client_id,
        )
        token_response = {
          access_token: access_token,
          refresh_token: grant.issue_refresh_token!,
          id_token: OidcIdTokenIssuer.call(
            resource: resource,
            client: oidc_client,
            nonce: nonce,
            auth_time: authentication_time,
            sid: grant.public_id,
          ),
          expires_in: 300,
          refresh_token_expires_in: 600,
        }
        token_result = OidcOpTokenClient::Result.new(outcome: :success, token_response:, error: nil)
        jwks_uri = OidcIssuer.jwks_uri(resource_type).to_s
        previous_jwks_client = OidcOpJwksClient::CLIENTS.delete(jwks_uri)
        issuer_id = OidcIssuer.jwt_issuer_id_for_resource_type(resource_type)
        OidcOpJwksClient::CLIENTS[jwks_uri] = OidcOpJwksClient.new(
          jwks_uri: jwks_uri,
          fetcher: -> { JitSecurityJwtRegistry.jwks_for(issuer_id).deep_stringify_keys },
        )

        begin
          OidcOpTokenClient.stub(:authorization_code, token_result) do
            get(
              "/oidc/callback",
              params: {
                code: "public-callback-code",
                state: state,
                iss: OidcIssuer.for_resource_type(resource_type),
              },
            )
          end
        ensure
          OidcOpJwksClient::CLIENTS.delete(jwks_uri)
          OidcOpJwksClient::CLIENTS[jwks_uri] = previous_jwks_client if previous_jwks_client
        end

        expected_landing = target_case.fetch(:landing) || rp.fetch(:landing)

        assert_response :redirect, "#{rp.fetch(:client_id)} #{target_case.fetch(:label)}"
        assert_equal expected_landing, URI.parse(response.location).path,
                     "#{rp.fetch(:client_id)} #{target_case.fetch(:label)}"
        assert_nil session[OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY],
                   "#{rp.fetch(:client_id)} #{target_case.fetch(:label)} consumes its state"

        next unless rp.fetch(:client_id).start_with?("core-") && target_case.fetch(:label) == "without a target"

        get("/", params: { ri: "jp" })

        assert_response :success, "#{rp.fetch(:client_id)} keeps the signed-in root available"
        assert_nil response.location
      end
    end
  end
end
