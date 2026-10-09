# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/operator-capability-authorization.md, Support: com-realm Visitor pages. Every test grants the
# capabilities it relies on in its own body.
class Base::Org::Support::VisitorsControllerTest < ActionDispatch::IntegrationTest
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
  end

  test "an operator with no grant cannot list visitors" do
    http_headers_4 =
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
    get base_org_support_visitors_url(ri: "jp", host: @host),
        headers: http_headers_4,
        as: :json

    assert_response :forbidden
  end

  test "the com read capability lists visitors filtered by public id" do
    OperatorCapabilityGrant.create!(
      operator: @operator, granted_by_operator: @granter, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    http_headers_3 =
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
    get base_org_support_visitors_url(q: @visitor.public_id, ri: "jp", host: @host),
        headers: http_headers_3

    assert_response :ok
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal "base/org/support/visitors/index", inertia_component
    assert_equal [@visitor.public_id], inertia_props.fetch("rows").map { |row| row.fetch("key") }
    assert_equal @visitor.public_id, inertia_props.dig("search", "value")
    assert_equal "com", inertia_props.dig("context", "realm")
  end

  test "a public id matching no visitor lists no rows" do
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
    get base_org_support_visitors_url(q: "no_such_visitor", ri: "jp", host: @host),
        headers: http_headers_2

    assert_response :ok
    assert_empty inertia_props.fetch("rows")
  end

  test "the com read capability alone shows a visitor with no action and no enforcement section" do
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
    get base_org_support_visitor_url(@visitor.public_id, ri: "jp", host: @host),
        headers: http_headers_1

    assert_response :ok
    assert_equal "base/org/support/visitors/show", inertia_component
    assert_includes inertia_props.fetch("fields").map { |field| field.fetch("description") }, @visitor.public_id
    assert_empty inertia_props.fetch("actions")
    assert_empty inertia_props.fetch("sections")
  end

  test "revoke, enforcement apply, and enforcement read capabilities add their actions and section" do
    [
      OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM,
      OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_COM,
      OperatorCapabilityGrant::ENFORCEMENT_APPLY_COM,
      OperatorCapabilityGrant::ENFORCEMENT_READ_COM,
    ].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, granted_by_operator: @granter, origin: "grant",
        capability: capability, reason_code: "duty_assignment",
        starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end

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
    get base_org_support_visitor_url(@visitor.public_id, ri: "jp", host: @host),
        headers: http_headers_0

    assert_response :ok
    hrefs = inertia_props.fetch("actions").map { |action| action.fetch("href") }

    assert_equal 2, hrefs.size
    assert(hrefs.any? { |href| href.include?("/support/visitors/#{@visitor.public_id}/revocations/new") })
    assert(hrefs.any? { |href| href.include?("principal_public_id=#{@visitor.public_id}") })
    assert_equal 1, inertia_props.fetch("sections").size
  end
end
