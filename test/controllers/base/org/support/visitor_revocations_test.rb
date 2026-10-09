# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/operator-capability-authorization.md, Support: forced revocation of a com-realm Visitor's
# sessions. Every test grants the capabilities and Step-Up scope it relies on in its own body.
class Base::Org::Support::VisitorRevocationsTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @operator = operators(:one)
    @granter = operators(:two)
    @operator_token = OperatorToken.create!(
      staff: @operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    @visitor = visitors(:reserved_visitor)
    # The compliance row normally comes from migration 20260926130000 (365 days, decided 2026-09-26);
    # a schema-only load skips that insert, so the test ensures it with the same value.
    ChronicleRetentionPolicy.find_or_create_by!(code: "compliance") do |policy|
      policy.name = "Compliance"
      policy.duration_days = 365
      policy.permanent = false
    end
  end

  test "the read capability alone cannot open the revocation screen" do
    OperatorCapabilityGrant.create!(
      operator: @operator, granted_by_operator: @granter, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    http_headers_2 =
      begin
        rp_headers = as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "org"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org"
            else "#{rp_family}-#{rp_surface}"
            end
          rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OperatorRpSession.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
            rp_now = Time.current
            rp_session = OperatorRpSession.create!(
              operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.staff, host: rp_host, resource_type: "operator",
                              session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                              oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                              expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                              issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                              subject: OidcSubject.for(
                                rp_token.staff,
                                resource_type: "operator",
                              ), client_id: rp_client.client_id,
            )
            @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    get new_base_org_support_visitor_revocation_url(@visitor.public_id, ri: "jp", host: @host),
        headers: http_headers_2,
        as: :json

    assert_response :forbidden
  end

  test "an unknown visitor is not found" do
    OperatorCapabilityGrant.create!(
      operator: @operator, granted_by_operator: @granter, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    http_headers_1 =
      begin
        rp_headers = as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "org"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org"
            else "#{rp_family}-#{rp_surface}"
            end
          rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OperatorRpSession.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
            rp_now = Time.current
            rp_session = OperatorRpSession.create!(
              operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.staff, host: rp_host, resource_type: "operator",
                              session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                              oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                              expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                              issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                              subject: OidcSubject.for(
                                rp_token.staff,
                                resource_type: "operator",
                              ), client_id: rp_client.client_id,
            )
            @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    get new_base_org_support_visitor_revocation_url("no_such_visitor", ri: "jp", host: @host),
        headers: http_headers_1

    assert_response :not_found
  end

  test "with Step-Up the screen renders, the revocation ends sessions, and the result page shows it" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_COM,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, granted_by_operator: @granter, origin: "grant",
        capability: capability, reason_code: "duty_assignment",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns(
      last_step_up_at: Time.current,
      last_step_up_scope: "support_session_revoke",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    token = VisitorToken.create!(visitor_id: @visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    headers =
      begin
        rp_headers = as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "org"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org"
            else "#{rp_family}-#{rp_surface}"
            end
          rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OperatorRpSession.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
            rp_now = Time.current
            rp_session = OperatorRpSession.create!(
              operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.staff, host: rp_host, resource_type: "operator",
                              session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                              oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                              expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                              issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                              subject: OidcSubject.for(
                                rp_token.staff,
                                resource_type: "operator",
                              ), client_id: rp_client.client_id,
            )
            @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end

    get new_base_org_support_visitor_revocation_url(@visitor.public_id, ri: "jp", host: @host), headers: headers

    assert_response :ok
    assert_equal "base/org/support/revocations/new", inertia_component
    assert_equal "com", inertia_props.dig("context", "realm")

    operation_id = SecureRandom.uuid
    post base_org_support_visitor_revocations_url(@visitor.public_id, host: @host),
         params: { reason_code: "security_incident", ticket_id: "SEC-635", operation_id: operation_id },
         headers: headers

    assert_response :see_other
    assert_redirected_to base_org_support_visitor_revocation_url(@visitor.public_id, operation_id, host: @host)
    assert_predicate token.reload, :revoked?
    chronicle = Chronicle.find_by!(event_uuid: operation_id)

    assert_equal "com", chronicle.metadata.fetch("realm")
    assert_equal ["Visitor", @visitor.id], [chronicle.subject_type, chronicle.subject_id]

    get base_org_support_visitor_revocation_url(@visitor.public_id, operation_id, ri: "jp", host: @host),
        headers: headers

    assert_response :ok
    assert_equal "base/org/support/revocations/show", inertia_component
    assert_includes inertia_props.fetch("fields").map { |field| field.fetch("description") }, @operator.public_id
  end

  test "an unknown reason code re-renders the screen with the submitted values and revokes nothing" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_COM,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, granted_by_operator: @granter, origin: "grant",
        capability: capability, reason_code: "duty_assignment",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns(
      last_step_up_at: Time.current,
      last_step_up_scope: "support_session_revoke",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    token = VisitorToken.create!(visitor_id: @visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    http_headers_0 =
      begin
        rp_headers = as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "org"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org"
            else "#{rp_family}-#{rp_surface}"
            end
          rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OperatorRpSession.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
            rp_now = Time.current
            rp_session = OperatorRpSession.create!(
              operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.staff, host: rp_host, resource_type: "operator",
                              session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                              oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                              expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                              issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                              subject: OidcSubject.for(
                                rp_token.staff,
                                resource_type: "operator",
                              ), client_id: rp_client.client_id,
            )
            @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    post base_org_support_visitor_revocations_url(@visitor.public_id, host: @host),
         params: { reason_code: "not_a_reason", ticket_id: "SEC-635", operation_id: SecureRandom.uuid },
         headers: http_headers_0

    assert_response :unprocessable_content
    assert_equal "base/org/support/revocations/new", inertia_component
    assert_not_predicate token.reload, :revoked?
  end
end
