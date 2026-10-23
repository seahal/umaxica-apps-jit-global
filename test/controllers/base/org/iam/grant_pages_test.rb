# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/operator-capability-authorization.md, IAM: the grant list and grant detail pages. Every test
# states the grants it relies on in its own body.
class Base::Org::Iam::GrantPagesTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @reader = operators(:one)
    @other = operators(:two)
    @reader_token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: @reader,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
  end

  test "iam.capability.read lists grants filtered by operator, without a new-grant action" do
    OperatorCapabilityGrant.create!(
      operator: @reader, origin: "bootstrap", capability: OperatorCapabilityGrant::IAM_CAPABILITY_READ,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    other_grant = OperatorCapabilityGrant.create!(
      operator: @other, granted_by_operator: @reader, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    http_headers_2 =
      begin
        rp_headers = as_staff_headers(@reader, host: @host, session_public_id: @reader_token.public_id)
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
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{rp_family}-#{rp_surface}-jp"
            end
          rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OpOrgGrant.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OpOrgGrant.create!(
              authentication_epoch: 0,
              operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "operator",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
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
    get base_org_iam_grants_url(q: @other.public_id, ri: "jp", host: @host),
        headers: http_headers_2

    assert_response :ok
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal "base/org/iam/grants/index", inertia_component
    assert_equal [other_grant.public_id], inertia_props.fetch("rows").map { |row| row.fetch("key") }
    assert_equal I18n.t("base.org.admin.grants.states.in_force", locale: :ja),
                 inertia_props.fetch("rows").first.fetch("cells")[3]
    assert_empty inertia_props.fetch("actions"), "an operator holding only IAM capabilities has nothing to delegate"
  end

  test "each grant state is labelled: revoked, pending, and expired" do
    OperatorCapabilityGrant.create!(
      operator: @reader, origin: "bootstrap", capability: OperatorCapabilityGrant::IAM_CAPABILITY_READ,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    revoked = OperatorCapabilityGrant.create!(
      operator: @other, granted_by_operator: @reader, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    revoked.revoke!(by: @reader, reason_code: "duty_ended")
    pending = OperatorCapabilityGrant.create!(
      operator: @other, granted_by_operator: @reader, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM, reason_code: "duty_assignment",
      starts_at: 1.hour.from_now, expires_at: 1.day.from_now,
    )
    expired = OperatorCapabilityGrant.create!(
      operator: @other, granted_by_operator: @reader, origin: "grant",
      capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP, reason_code: "duty_assignment",
      starts_at: 2.days.ago, expires_at: 1.day.ago,
    )

    http_headers_1 =
      begin
        rp_headers = as_staff_headers(@reader, host: @host, session_public_id: @reader_token.public_id)
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
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{rp_family}-#{rp_surface}-jp"
            end
          rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OpOrgGrant.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OpOrgGrant.create!(
              authentication_epoch: 0,
              operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "operator",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
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
    get base_org_iam_grants_url(q: @other.public_id, ri: "jp", host: @host),
        headers: http_headers_1

    assert_response :ok
    states = inertia_props.fetch("rows").to_h { |row| [row.fetch("key"), row.fetch("cells")[3]] }

    assert_equal I18n.t("base.org.admin.grants.states.revoked", locale: :ja), states.fetch(revoked.public_id)
    assert_equal I18n.t("base.org.admin.grants.states.pending", locale: :ja), states.fetch(pending.public_id)
    assert_equal I18n.t("base.org.admin.grants.states.expired", locale: :ja), states.fetch(expired.public_id)
  end

  test "a grant detail offers revocation only to a holder of iam.capability.revoke" do
    OperatorCapabilityGrant.create!(
      operator: @reader, origin: "bootstrap", capability: OperatorCapabilityGrant::IAM_CAPABILITY_READ,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    grant = OperatorCapabilityGrant.create!(
      operator: @other, granted_by_operator: @reader, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    headers =
      begin
        rp_headers = as_staff_headers(@reader, host: @host, session_public_id: @reader_token.public_id)
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
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{rp_family}-#{rp_surface}-jp"
            end
          rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OpOrgGrant.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OpOrgGrant.create!(
              authentication_epoch: 0,
              operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "operator",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
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

    get base_org_iam_grant_url(grant.public_id, ri: "jp", host: @host), headers: headers

    assert_response :ok
    assert_equal "base/org/iam/grants/show", inertia_component
    assert_includes inertia_props.fetch("fields").map { |field| field.fetch("description") }, @reader.public_id
    assert_empty inertia_props.fetch("actions")

    OperatorCapabilityGrant.create!(
      operator: @reader, origin: "bootstrap", capability: OperatorCapabilityGrant::IAM_CAPABILITY_REVOKE,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    get base_org_iam_grant_url(grant.public_id, ri: "jp", host: @host), headers: headers

    assert_response :ok
    assert_equal [new_base_org_iam_grant_revocation_path(grant.public_id, ri: "jp")],
                 inertia_props.fetch("actions").map { |action| action.fetch("href") }
  end

  test "an unknown grant public id is not found" do
    OperatorCapabilityGrant.create!(
      operator: @reader, origin: "bootstrap", capability: OperatorCapabilityGrant::IAM_CAPABILITY_READ,
      reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    http_headers_0 =
      begin
        rp_headers = as_staff_headers(@reader, host: @host, session_public_id: @reader_token.public_id)
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
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{rp_family}-#{rp_surface}-jp"
            end
          rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OpOrgGrant.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OpOrgGrant.create!(
              authentication_epoch: 0,
              operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "operator",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
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
    get base_org_iam_grant_url("no_such_grant", ri: "jp", host: @host),
        headers: http_headers_0

    assert_response :not_found
  end
end
