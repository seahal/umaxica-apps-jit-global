# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/unified-enforcement.md and adr/operator-capability-authorization.md. Every test states the
# capability grants it relies on in its own body: being an operator authorizes nothing on its own.
class Base::Org::Support::EnforcementCasesControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []
  skip_transactional_tests_for_database :app_zenith
  skip_transactional_tests_for_database :org_zenith
  skip_transactional_tests_for_database :op_base_org

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    @approver = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    [@operator, @approver].each do |operator|
      2.times do |index|
        OperatorPasskey.create!(
          staff_id: operator.id,
          webauthn_id: SecureRandom.urlsafe_base64(32),
          external_id: SecureRandom.uuid,
          public_key: "enforcement-test-public-key",
          sign_count: 0,
          description: "Enforcement test Passkey #{index + 1}",
          status_id: OperatorPasskeyStatus::ACTIVE,
        )
      end
    end
    @client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @operator_token = OperatorToken.create!(
      authentication_epoch: 0,
      staff_id: @operator.id,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    @approver_token = OperatorToken.create!(
      authentication_epoch: 0,
      staff_id: @approver.id,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
  end

  teardown do
    operator_ids = [@operator&.id, @approver&.id].compact
    operator_public_ids = [@operator&.public_id, @approver&.public_id].compact
    token_ids = [@operator_token&.id, @approver_token&.id].compact
    client_ids = [@client&.id].compact
    client_public_ids = [@client&.public_id].compact

    app_cases = AppEnforcementCase.where(applied_by_operator_public_id: operator_public_ids)
    app_cases = app_cases.or(AppEnforcementCase.where(principal_public_id: client_public_ids))
    org_cases = OrgEnforcementCase.where(applied_by_operator_public_id: operator_public_ids)
    org_cases = org_cases.or(OrgEnforcementCase.where(principal_public_id: operator_public_ids))

    AppEnforcementAppeal.where(app_enforcement_case_id: app_cases.select(:id)).delete_all
    AppEnforcementPrincipalEffect.where(app_enforcement_case_id: app_cases.select(:id)).delete_all
    AppEnforcementAuthenticationMethodEffect.where(app_enforcement_case_id: app_cases.select(:id)).delete_all
    AppEnforcementIdentifierEffect.where(app_enforcement_case_id: app_cases.select(:id)).delete_all
    AppEnforcementPrincipalLink.where(app_enforcement_case_id: app_cases.select(:id)).delete_all
    app_cases.delete_all

    OrgEnforcementAppeal.where(org_enforcement_case_id: org_cases.select(:id)).delete_all
    OrgEnforcementPrincipalEffect.where(org_enforcement_case_id: org_cases.select(:id)).delete_all
    OrgEnforcementAuthenticationMethodEffect.where(org_enforcement_case_id: org_cases.select(:id)).delete_all
    OrgEnforcementIdentifierEffect.where(org_enforcement_case_id: org_cases.select(:id)).delete_all
    OrgEnforcementPrincipalLink.where(org_enforcement_case_id: org_cases.select(:id)).delete_all
    org_cases.delete_all

    OperatorCapabilityGrant.where(operator_id: operator_ids).or(
      OperatorCapabilityGrant.where(granted_by_operator_id: operator_ids),
    ).delete_all
    OperatorPasskey.where(staff_id: operator_ids).delete_all
    OpOrgGrant.where(operator_token_id: token_ids).includes(:logout_hint).destroy_all
    device_session_ids = OperatorToken.where(id: token_ids).pluck(:device_session_id).compact
    OperatorDeviceSession.where(id: device_session_ids).update_all(current_refresh_token_id: nil)
    OperatorToken.where(id: token_ids).delete_all
    OperatorDeviceSession.where(id: device_session_ids).delete_all

    AppIdentityAuthenticationEvent.where(actor_ref: client_ids.map(&:to_s)).delete_all
    OrgIdentityAuthenticationEvent.where(actor_ref: operator_ids.map(&:to_s)).delete_all
    Client.where(id: client_ids).delete_all
    Operator.where(id: operator_ids).delete_all
  end

  test "an operator with no grant is refused the case list" do
    http_headers_20 =
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
            rp_local_session = RpCallbackCommitter.call(
              cell: RpCellBinding.for_client(rp_client.client_id),
              issuer: OidcIssuer.for_client(rp_client),
              subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
              sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
            ).session
            raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

            @base_browser_rp_credentials[rp_key] = [
              rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
            ]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    get(
      base_org_support_app_enforcement_cases_url(host: @host),
      headers: http_headers_20,
      as: :json,
    )

    assert_response :forbidden
  end

  test "the read capability lists cases without Step-Up but does not allow opening one" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @approver,
      origin: "grant",
      capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    http_headers_19 =
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
            rp_local_session = RpCallbackCommitter.call(
              cell: RpCellBinding.for_client(rp_client.client_id),
              issuer: OidcIssuer.for_client(rp_client),
              subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
              sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
            ).session
            raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

            @base_browser_rp_credentials[rp_key] = [
              rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
            ]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    get(
      base_org_support_app_enforcement_cases_url(host: @host),
      headers: http_headers_19,
      as: :json,
    )

    assert_response :ok

    http_headers_18 =
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
            rp_local_session = RpCallbackCommitter.call(
              cell: RpCellBinding.for_client(rp_client.client_id),
              issuer: OidcIssuer.for_client(rp_client),
              subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
              sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
            ).session
            raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

            @base_browser_rp_credentials[rp_key] = [
              rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
            ]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    post(
      base_org_support_app_enforcement_cases_url(host: @host),
      params: { enforcement_case: { kind: "cooldown", principal_public_id: @client.public_id } },
      headers: http_headers_18,
      as: :json,
    )

    assert_response :forbidden
  end

  test "an app grant does not reach the org realm" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @approver,
      origin: "grant",
      capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    http_headers_16 =
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
            rp_local_session = RpCallbackCommitter.call(
              cell: RpCellBinding.for_client(rp_client.client_id),
              issuer: OidcIssuer.for_client(rp_client),
              subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
              sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
            ).session
            raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

            @base_browser_rp_credentials[rp_key] = [
              rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
            ]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    get(
      base_org_support_org_enforcement_cases_url(host: @host),
      headers: http_headers_16,
      as: :json,
    )

    assert_response :forbidden
  end

  test "without a grant the operator is refused before any Step-Up is asked for" do
    http_headers_14 =
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
            rp_local_session = RpCallbackCommitter.call(
              cell: RpCellBinding.for_client(rp_client.client_id),
              issuer: OidcIssuer.for_client(rp_client),
              subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
              sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
            ).session
            raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

            @base_browser_rp_credentials[rp_key] = [
              rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
            ]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    post(
      base_org_support_app_enforcement_cases_url(host: @host),
      params: { enforcement_case: { kind: "cooldown", principal_public_id: @client.public_id } },
      headers: http_headers_14,
      as: :json,
    )

    assert_response :forbidden
    assert_not_includes response.body, "Step-up"
  end

  test "the apply capability without Step-Up does not open a case" do
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end

    assert_no_difference -> { AppEnforcementCase.count } do
      http_headers_13 =
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
                                       session_public_id: rp_token.public_id,
                                       base_session_public_id: rp_token.public_id,
                                       oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                       expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                       subject: OidcSubject.for(
                                         rp_token.actor_record,
                                         resource_type: "operator",
                                       ), client_id: rp_client.client_id,
              )
              rp_local_session = RpCallbackCommitter.call(
                cell: RpCellBinding.for_client(rp_client.client_id),
                issuer: OidcIssuer.for_client(rp_client),
                subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
                sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
              ).session
              raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

              @base_browser_rp_credentials[rp_key] = [
                rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
              ]
            end
            if @base_browser_rp_credentials[rp_key]
              rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
              rp_cookie = [
                rp_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
                "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
              ].join("; ")
              rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
            end
          end
          rp_headers
        end
      post(
        base_org_support_app_enforcement_cases_url(host: @host),
        params: {
          enforcement_case: {
            kind: "cooldown",
            duration_mode: "timed",
            visibility: "visible",
            release_mode: "automatic",
            effective_at: Time.current,
            expires_at: 1.day.from_now,
            reason_code: "abuse",
            principal_public_id: @client.public_id,
          },
        },
        headers: http_headers_13,
        as: :json,
      )
    end

    assert_response :unauthorized
    assert_match(/Bearer error="insufficient_user_authentication"/, response.headers.fetch("WWW-Authenticate"))
    assert_match(/max_age="300"/, response.headers.fetch("WWW-Authenticate"))
    assert_equal "private, no-store", response.headers.fetch("Cache-Control")
  end

  test "recent Step-Up evidence is reusable for a different protected operation" do
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    step_up_token = @operator_token
    step_up_actor = @operator
    step_up_now = OpBaseOrgRecord.database_now
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.reload
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_acr = StepUpEvidenceResolver::STEP_UP_ACR
    step_up_amr = ["passkey"]
    step_up_event = OpOrgGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch,
      operator_token: step_up_token,
      oidc_client_id: step_up_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(step_up_now.to_time.to_i).utc,
      oidc_acr: step_up_acr,
      oidc_amr: JSON.generate(step_up_amr),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_refresh_token = step_up_event.issue_refresh_token!
    step_up_access_token = AuthenticationTokenService.encode(
      step_up_token.actor_record,
      host: URI.parse(@host).host,
      resource_type: "operator",
      session_public_id: step_up_token.public_id,
      base_session_public_id: step_up_token.public_id,
      oidc_sid: step_up_event.public_id,
      oidc_jti: step_up_event.oidc_jti,
      expires_at: step_up_now + 10.minutes,
      scopes: %w(openid profile),
      acr: step_up_acr,
      amr: step_up_amr,
      auth_time: step_up_now.to_time.to_i,
      client_id: step_up_client.client_id,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
      issuer: OidcIssuer.for_client(step_up_client),
      audiences: [step_up_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
    )
    step_up_local_session = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(step_up_client.client_id),
      issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
      sid: step_up_event.public_id, absolute_expires_at: 1.hour.from_now,
    ).session
    raise RuntimeError, "Base ORG Step-Up RP session enrollment failed" unless step_up_local_session

    (@base_browser_rp_credentials ||= {})[[step_up_client.client_id, step_up_token.public_id]] = [
      step_up_access_token, step_up_refresh_token, step_up_local_session.public_id,
    ]

    http_headers_12 =
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
            rp_local_session = RpCallbackCommitter.call(
              cell: RpCellBinding.for_client(rp_client.client_id),
              issuer: OidcIssuer.for_client(rp_client),
              subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
              sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
            ).session
            raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

            @base_browser_rp_credentials[rp_key] = [
              rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
            ]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    post(
      base_org_support_app_enforcement_cases_url(host: @host),
      params: {
        enforcement_case: {
          kind: "cooldown",
          duration_mode: "timed",
          visibility: "visible",
          release_mode: "automatic",
          effective_at: Time.current,
          expires_at: 1.day.from_now,
          reason_code: "abuse",
          principal_public_id: @client.public_id,
        },
      },
      headers: http_headers_12,
      as: :json,
    )

    assert_response :created
    assert_equal "active", response.parsed_body.fetch("state")
  end

  test "operator with apply capability and Step-Up opens a cooldown case that applies immediately" do
    client = @client
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    step_up_token = @operator_token
    step_up_actor = @operator
    step_up_now = OpBaseOrgRecord.database_now
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.reload
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_acr = StepUpEvidenceResolver::STEP_UP_ACR
    step_up_amr = ["passkey"]
    step_up_event = OpOrgGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch,
      operator_token: step_up_token,
      oidc_client_id: step_up_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(step_up_now.to_time.to_i).utc,
      oidc_acr: step_up_acr,
      oidc_amr: JSON.generate(step_up_amr),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_refresh_token = step_up_event.issue_refresh_token!
    step_up_access_token = AuthenticationTokenService.encode(
      step_up_token.actor_record,
      host: URI.parse(@host).host,
      resource_type: "operator",
      session_public_id: step_up_token.public_id,
      base_session_public_id: step_up_token.public_id,
      oidc_sid: step_up_event.public_id,
      oidc_jti: step_up_event.oidc_jti,
      expires_at: step_up_now + 10.minutes,
      scopes: %w(openid profile),
      acr: step_up_acr,
      amr: step_up_amr,
      auth_time: step_up_now.to_time.to_i,
      client_id: step_up_client.client_id,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
      issuer: OidcIssuer.for_client(step_up_client),
      audiences: [step_up_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
    )
    step_up_local_session = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(step_up_client.client_id),
      issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
      sid: step_up_event.public_id, absolute_expires_at: 1.hour.from_now,
    ).session
    raise RuntimeError, "Base ORG Step-Up RP session enrollment failed" unless step_up_local_session

    (@base_browser_rp_credentials ||= {})[[step_up_client.client_id, step_up_token.public_id]] = [
      step_up_access_token, step_up_refresh_token, step_up_local_session.public_id,
    ]

    http_headers_11 =
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
            rp_local_session = RpCallbackCommitter.call(
              cell: RpCellBinding.for_client(rp_client.client_id),
              issuer: OidcIssuer.for_client(rp_client),
              subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
              sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
            ).session
            raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

            @base_browser_rp_credentials[rp_key] = [
              rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
            ]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    post(
      base_org_support_app_enforcement_cases_url(host: @host),
      params: {
        enforcement_case: {
          kind: "cooldown",
          duration_mode: "timed",
          visibility: "visible",
          release_mode: "automatic",
          effective_at: Time.current,
          expires_at: 1.day.from_now,
          reason_code: "abuse",
          principal_public_id: client.public_id,
        },
      },
      headers: http_headers_11,
      as: :json,
    )

    assert_response :created
    body = response.parsed_body

    assert_equal "active", body.fetch("state")
    assert_equal client.public_id, body.fetch("principal_public_id")
    assert_equal @operator.public_id, body.fetch("applied_by_operator_public_id")
  end

  test "a case naming no existing principal is not found" do
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    step_up_token = @operator_token
    step_up_actor = @operator
    step_up_now = OpBaseOrgRecord.database_now
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.reload
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_acr = StepUpEvidenceResolver::STEP_UP_ACR
    step_up_amr = ["passkey"]
    step_up_event = OpOrgGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch,
      operator_token: step_up_token,
      oidc_client_id: step_up_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(step_up_now.to_time.to_i).utc,
      oidc_acr: step_up_acr,
      oidc_amr: JSON.generate(step_up_amr),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_refresh_token = step_up_event.issue_refresh_token!
    step_up_access_token = AuthenticationTokenService.encode(
      step_up_token.actor_record,
      host: URI.parse(@host).host,
      resource_type: "operator",
      session_public_id: step_up_token.public_id,
      base_session_public_id: step_up_token.public_id,
      oidc_sid: step_up_event.public_id,
      oidc_jti: step_up_event.oidc_jti,
      expires_at: step_up_now + 10.minutes,
      scopes: %w(openid profile),
      acr: step_up_acr,
      amr: step_up_amr,
      auth_time: step_up_now.to_time.to_i,
      client_id: step_up_client.client_id,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
      issuer: OidcIssuer.for_client(step_up_client),
      audiences: [step_up_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
    )
    step_up_local_session = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(step_up_client.client_id),
      issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
      sid: step_up_event.public_id, absolute_expires_at: 1.hour.from_now,
    ).session
    raise RuntimeError, "Base ORG Step-Up RP session enrollment failed" unless step_up_local_session

    (@base_browser_rp_credentials ||= {})[[step_up_client.client_id, step_up_token.public_id]] = [
      step_up_access_token, step_up_refresh_token, step_up_local_session.public_id,
    ]

    # A visitor principal no longer exists; any unknown principal references stay not-found.
    ["NO0SUCH0PRINCIPAL"].each do |principal_public_id|
      assert_no_difference -> { AppEnforcementCase.count } do
        http_headers_10 =
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
                                         session_public_id: rp_token.public_id,
                                         base_session_public_id: rp_token.public_id,
                                         oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                         expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                         subject: OidcSubject.for(
                                           rp_token.actor_record,
                                           resource_type: "operator",
                                         ), client_id: rp_client.client_id,
                )
                rp_local_session = RpCallbackCommitter.call(
                  cell: RpCellBinding.for_client(rp_client.client_id),
                  issuer: OidcIssuer.for_client(rp_client),
                  subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
                  sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
                ).session
                raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

                @base_browser_rp_credentials[rp_key] = [
                  rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
                ]
              end
              if @base_browser_rp_credentials[rp_key]
                rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
                rp_cookie = [
                  rp_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
                  "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
                ].join("; ")
                rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
              end
            end
            rp_headers
          end
        post(
          base_org_support_app_enforcement_cases_url(host: @host),
          params: {
            enforcement_case: {
              kind: "cooldown",
              duration_mode: "timed",
              visibility: "visible",
              release_mode: "automatic",
              effective_at: Time.current,
              expires_at: 1.day.from_now,
              reason_code: "abuse",
              principal_public_id: principal_public_id,
            },
          },
          headers: http_headers_10,
          as: :json,
        )
      end

      assert_response :not_found
    end
  end

  test "a break-glass request on create is refused rather than trusted" do
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    step_up_token = @operator_token
    step_up_actor = @operator
    step_up_now = OpBaseOrgRecord.database_now
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.reload
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_acr = StepUpEvidenceResolver::STEP_UP_ACR
    step_up_amr = ["passkey"]
    step_up_event = OpOrgGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch,
      operator_token: step_up_token,
      oidc_client_id: step_up_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(step_up_now.to_time.to_i).utc,
      oidc_acr: step_up_acr,
      oidc_amr: JSON.generate(step_up_amr),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_refresh_token = step_up_event.issue_refresh_token!
    step_up_access_token = AuthenticationTokenService.encode(
      step_up_token.actor_record,
      host: URI.parse(@host).host,
      resource_type: "operator",
      session_public_id: step_up_token.public_id,
      base_session_public_id: step_up_token.public_id,
      oidc_sid: step_up_event.public_id,
      oidc_jti: step_up_event.oidc_jti,
      expires_at: step_up_now + 10.minutes,
      scopes: %w(openid profile),
      acr: step_up_acr,
      amr: step_up_amr,
      auth_time: step_up_now.to_time.to_i,
      client_id: step_up_client.client_id,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
      issuer: OidcIssuer.for_client(step_up_client),
      audiences: [step_up_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
    )
    step_up_local_session = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(step_up_client.client_id),
      issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
      sid: step_up_event.public_id, absolute_expires_at: 1.hour.from_now,
    ).session
    raise RuntimeError, "Base ORG Step-Up RP session enrollment failed" unless step_up_local_session

    (@base_browser_rp_credentials ||= {})[[step_up_client.client_id, step_up_token.public_id]] = [
      step_up_access_token, step_up_refresh_token, step_up_local_session.public_id,
    ]

    assert_no_difference -> { AppEnforcementCase.count } do
      http_headers_9 =
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
                                       session_public_id: rp_token.public_id,
                                       base_session_public_id: rp_token.public_id,
                                       oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                       expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                       subject: OidcSubject.for(
                                         rp_token.actor_record,
                                         resource_type: "operator",
                                       ), client_id: rp_client.client_id,
              )
              rp_local_session = RpCallbackCommitter.call(
                cell: RpCellBinding.for_client(rp_client.client_id),
                issuer: OidcIssuer.for_client(rp_client),
                subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
                sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
              ).session
              raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

              @base_browser_rp_credentials[rp_key] = [
                rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
              ]
            end
            if @base_browser_rp_credentials[rp_key]
              rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
              rp_cookie = [
                rp_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
                "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
              ].join("; ")
              rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
            end
          end
          rp_headers
        end
      post(
        base_org_support_app_enforcement_cases_url(host: @host),
        params: {
          enforcement_case: {
            kind: "permanent_ban",
            duration_mode: "permanent",
            visibility: "visible",
            release_mode: "break_glass_only",
            effective_at: Time.current,
            reason_code: "abuse",
            principal_public_id: @client.public_id,
            break_glass: true,
            break_glass_approved_by_operator_public_id: @approver.public_id,
          },
        },
        headers: http_headers_9,
        as: :json,
      )
    end

    assert_response :unprocessable_content
  end

  test "an approver named in the create request is ignored; the Case waits for a real approval" do
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    step_up_token = @operator_token
    step_up_actor = @operator
    step_up_now = OpBaseOrgRecord.database_now
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.reload
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_acr = StepUpEvidenceResolver::STEP_UP_ACR
    step_up_amr = ["passkey"]
    step_up_event = OpOrgGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch,
      operator_token: step_up_token,
      oidc_client_id: step_up_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(step_up_now.to_time.to_i).utc,
      oidc_acr: step_up_acr,
      oidc_amr: JSON.generate(step_up_amr),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_refresh_token = step_up_event.issue_refresh_token!
    step_up_access_token = AuthenticationTokenService.encode(
      step_up_token.actor_record,
      host: URI.parse(@host).host,
      resource_type: "operator",
      session_public_id: step_up_token.public_id,
      base_session_public_id: step_up_token.public_id,
      oidc_sid: step_up_event.public_id,
      oidc_jti: step_up_event.oidc_jti,
      expires_at: step_up_now + 10.minutes,
      scopes: %w(openid profile),
      acr: step_up_acr,
      amr: step_up_amr,
      auth_time: step_up_now.to_time.to_i,
      client_id: step_up_client.client_id,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
      issuer: OidcIssuer.for_client(step_up_client),
      audiences: [step_up_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
    )
    step_up_local_session = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(step_up_client.client_id),
      issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
      sid: step_up_event.public_id, absolute_expires_at: 1.hour.from_now,
    ).session
    raise RuntimeError, "Base ORG Step-Up RP session enrollment failed" unless step_up_local_session

    (@base_browser_rp_credentials ||= {})[[step_up_client.client_id, step_up_token.public_id]] = [
      step_up_access_token, step_up_refresh_token, step_up_local_session.public_id,
    ]

    http_headers_8 =
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
            rp_local_session = RpCallbackCommitter.call(
              cell: RpCellBinding.for_client(rp_client.client_id),
              issuer: OidcIssuer.for_client(rp_client),
              subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
              sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
            ).session
            raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

            @base_browser_rp_credentials[rp_key] = [
              rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
            ]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    post(
      base_org_support_app_enforcement_cases_url(host: @host),
      params: {
        enforcement_case: {
          kind: "permanent_ban",
          duration_mode: "permanent",
          visibility: "hidden",
          release_mode: "break_glass_only",
          effective_at: Time.current,
          reason_code: "abuse",
          principal_public_id: @client.public_id,
          approved_by_operator_public_id: @approver.public_id,
        },
      },
      headers: http_headers_8,
      as: :json,
    )

    assert_response :accepted
    the_case = AppEnforcementCase.find_by!(public_id: response.parsed_body.fetch("public_id"))

    assert_equal "pending_approval", the_case.state
    assert_nil the_case.approved_by_operator_public_id
    assert_not_predicate the_case.identifier_effects, :exists?
  end

  test "a second operator with the approve capability approves, and the audit event names them" do
    client = @client
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "hidden",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: @operator.public_id,
      state: "pending_approval",
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_APPROVE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @approver,
        granted_by_operator: @operator,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    step_up_token = @approver_token
    step_up_actor = @approver
    step_up_now = OpBaseOrgRecord.database_now
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.reload
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_acr = StepUpEvidenceResolver::STEP_UP_ACR
    step_up_amr = ["passkey"]
    step_up_event = OpOrgGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch,
      operator_token: step_up_token,
      oidc_client_id: step_up_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(step_up_now.to_time.to_i).utc,
      oidc_acr: step_up_acr,
      oidc_amr: JSON.generate(step_up_amr),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_refresh_token = step_up_event.issue_refresh_token!
    step_up_access_token = AuthenticationTokenService.encode(
      step_up_token.actor_record,
      host: URI.parse(@host).host,
      resource_type: "operator",
      session_public_id: step_up_token.public_id,
      base_session_public_id: step_up_token.public_id,
      oidc_sid: step_up_event.public_id,
      oidc_jti: step_up_event.oidc_jti,
      expires_at: step_up_now + 10.minutes,
      scopes: %w(openid profile),
      acr: step_up_acr,
      amr: step_up_amr,
      auth_time: step_up_now.to_time.to_i,
      client_id: step_up_client.client_id,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
      issuer: OidcIssuer.for_client(step_up_client),
      audiences: [step_up_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
    )
    step_up_local_session = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(step_up_client.client_id),
      issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
      sid: step_up_event.public_id, absolute_expires_at: 1.hour.from_now,
    ).session
    raise RuntimeError, "Base ORG Step-Up RP session enrollment failed" unless step_up_local_session

    (@base_browser_rp_credentials ||= {})[[step_up_client.client_id, step_up_token.public_id]] = [
      step_up_access_token, step_up_refresh_token, step_up_local_session.public_id,
    ]

    http_headers_7 =
      begin
        rp_headers = as_staff_headers(@approver, host: @host, session_public_id: @approver_token.public_id)
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
            rp_local_session = RpCallbackCommitter.call(
              cell: RpCellBinding.for_client(rp_client.client_id),
              issuer: OidcIssuer.for_client(rp_client),
              subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
              sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
            ).session
            raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

            @base_browser_rp_credentials[rp_key] = [
              rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
            ]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    post(
      base_org_support_app_enforcement_case_approval_url(the_case.public_id, host: @host),
      params: { principal_effect: { access_blocking: true } },
      headers: http_headers_7,
      as: :json,
    )

    assert_response :ok
    the_case.reload

    assert_equal "active", the_case.state
    assert_equal @approver.public_id, the_case.approved_by_operator_public_id
    assert_predicate client.reload, :admin_locked?
    approved = EnforcementEvent.find_by!(case_public_id: the_case.public_id, event_type: "approved")

    assert_equal @approver.public_id, approved.operator_public_id
  end

  test "a second approval of the same case is a conflict and does not apply it twice" do
    client = @client
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "hidden",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: @operator.public_id,
      state: "pending_approval",
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_APPROVE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @approver,
        granted_by_operator: @operator,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    step_up_token = @approver_token
    step_up_actor = @approver
    step_up_now = OpBaseOrgRecord.database_now
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.reload
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_acr = StepUpEvidenceResolver::STEP_UP_ACR
    step_up_amr = ["passkey"]
    step_up_event = OpOrgGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch,
      operator_token: step_up_token,
      oidc_client_id: step_up_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(step_up_now.to_time.to_i).utc,
      oidc_acr: step_up_acr,
      oidc_amr: JSON.generate(step_up_amr),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_refresh_token = step_up_event.issue_refresh_token!
    step_up_access_token = AuthenticationTokenService.encode(
      step_up_token.actor_record,
      host: URI.parse(@host).host,
      resource_type: "operator",
      session_public_id: step_up_token.public_id,
      base_session_public_id: step_up_token.public_id,
      oidc_sid: step_up_event.public_id,
      oidc_jti: step_up_event.oidc_jti,
      expires_at: step_up_now + 10.minutes,
      scopes: %w(openid profile),
      acr: step_up_acr,
      amr: step_up_amr,
      auth_time: step_up_now.to_time.to_i,
      client_id: step_up_client.client_id,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
      issuer: OidcIssuer.for_client(step_up_client),
      audiences: [step_up_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
    )
    step_up_local_session = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(step_up_client.client_id),
      issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
      sid: step_up_event.public_id, absolute_expires_at: 1.hour.from_now,
    ).session
    raise RuntimeError, "Base ORG Step-Up RP session enrollment failed" unless step_up_local_session

    (@base_browser_rp_credentials ||= {})[[step_up_client.client_id, step_up_token.public_id]] = [
      step_up_access_token, step_up_refresh_token, step_up_local_session.public_id,
    ]
    headers =
      begin
        rp_headers = as_staff_headers(@approver, host: @host, session_public_id: @approver_token.public_id)
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
            rp_local_session = RpCallbackCommitter.call(
              cell: RpCellBinding.for_client(rp_client.client_id),
              issuer: OidcIssuer.for_client(rp_client),
              subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
              sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
            ).session
            raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

            @base_browser_rp_credentials[rp_key] = [
              rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
            ]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end

    post(
      base_org_support_app_enforcement_case_approval_url(the_case.public_id, host: @host),
      params: { principal_effect: { access_blocking: true } },
      headers: headers,
      as: :json,
    )

    assert_response :ok

    replay_headers = headers.dup
    replay_cookie_values =
      replay_headers.fetch("Cookie").split("; ").to_h do |entry|
        entry.split("=", 2)
      end
    response.cookies.each { |name, value| replay_cookie_values[name] = value }
    replay_cookie = replay_cookie_values.map { |name, value| "#{name}=#{value}" }.join("; ")
    replay_headers = replay_headers.merge("Cookie" => replay_cookie, "HTTP_COOKIE" => replay_cookie)
    if replay_cookie_values.key?(AuthenticationBase::ACCESS_COOKIE_KEY)
      replay_headers["Authorization"] = "Bearer #{replay_cookie_values.fetch(AuthenticationBase::ACCESS_COOKIE_KEY)}"
    end
    post(
      base_org_support_app_enforcement_case_approval_url(the_case.public_id, host: @host),
      params: { principal_effect: { access_blocking: true } },
      headers: replay_headers,
      as: :json,
    )

    assert_response :conflict
    assert_equal "active", the_case.reload.state
    assert_equal 1, EnforcementEvent.where(case_public_id: the_case.public_id, event_type: "applied").count
  end

  test "the applying operator cannot approve their own case even holding the approve capability" do
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "hidden",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: @client.public_id,
      applied_by_operator_public_id: @operator.public_id,
      state: "pending_approval",
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_APPROVE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    step_up_token = @operator_token
    step_up_actor = @operator
    step_up_now = OpBaseOrgRecord.database_now
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.reload
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_acr = StepUpEvidenceResolver::STEP_UP_ACR
    step_up_amr = ["passkey"]
    step_up_event = OpOrgGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch,
      operator_token: step_up_token,
      oidc_client_id: step_up_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(step_up_now.to_time.to_i).utc,
      oidc_acr: step_up_acr,
      oidc_amr: JSON.generate(step_up_amr),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_refresh_token = step_up_event.issue_refresh_token!
    step_up_access_token = AuthenticationTokenService.encode(
      step_up_token.actor_record,
      host: URI.parse(@host).host,
      resource_type: "operator",
      session_public_id: step_up_token.public_id,
      base_session_public_id: step_up_token.public_id,
      oidc_sid: step_up_event.public_id,
      oidc_jti: step_up_event.oidc_jti,
      expires_at: step_up_now + 10.minutes,
      scopes: %w(openid profile),
      acr: step_up_acr,
      amr: step_up_amr,
      auth_time: step_up_now.to_time.to_i,
      client_id: step_up_client.client_id,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
      issuer: OidcIssuer.for_client(step_up_client),
      audiences: [step_up_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
    )
    step_up_local_session = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(step_up_client.client_id),
      issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
      sid: step_up_event.public_id, absolute_expires_at: 1.hour.from_now,
    ).session
    raise RuntimeError, "Base ORG Step-Up RP session enrollment failed" unless step_up_local_session

    (@base_browser_rp_credentials ||= {})[[step_up_client.client_id, step_up_token.public_id]] = [
      step_up_access_token, step_up_refresh_token, step_up_local_session.public_id,
    ]

    http_headers_6 =
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
            rp_local_session = RpCallbackCommitter.call(
              cell: RpCellBinding.for_client(rp_client.client_id),
              issuer: OidcIssuer.for_client(rp_client),
              subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
              sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
            ).session
            raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

            @base_browser_rp_credentials[rp_key] = [
              rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
            ]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    post(
      base_org_support_app_enforcement_case_approval_url(the_case.public_id, host: @host),
      params: {},
      headers: http_headers_6,
      as: :json,
    )

    assert_response :forbidden
    assert_equal "pending_approval", the_case.reload.state
  end

  test "an approver whose grant was revoked after Step-Up is refused" do
    the_case = AppEnforcementCase.create!(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "hidden",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: @client.public_id,
      applied_by_operator_public_id: @operator.public_id,
      state: "pending_approval",
    )
    grants =
      [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
       OperatorCapabilityGrant::ENFORCEMENT_APPROVE_APP,].map do |capability|
        OperatorCapabilityGrant.create!(
          operator: @approver,
          granted_by_operator: @operator,
          origin: "grant",
          capability: capability,
          reason_code: "duty_assignment",
          starts_at: 1.minute.ago,
          expires_at: 1.day.from_now,
        )
      end
    step_up_token = @approver_token
    step_up_actor = @approver
    step_up_now = OpBaseOrgRecord.database_now
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.reload
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_acr = StepUpEvidenceResolver::STEP_UP_ACR
    step_up_amr = ["passkey"]
    step_up_event = OpOrgGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch,
      operator_token: step_up_token,
      oidc_client_id: step_up_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(step_up_now.to_time.to_i).utc,
      oidc_acr: step_up_acr,
      oidc_amr: JSON.generate(step_up_amr),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_refresh_token = step_up_event.issue_refresh_token!
    step_up_access_token = AuthenticationTokenService.encode(
      step_up_token.actor_record,
      host: URI.parse(@host).host,
      resource_type: "operator",
      session_public_id: step_up_token.public_id,
      base_session_public_id: step_up_token.public_id,
      oidc_sid: step_up_event.public_id,
      oidc_jti: step_up_event.oidc_jti,
      expires_at: step_up_now + 10.minutes,
      scopes: %w(openid profile),
      acr: step_up_acr,
      amr: step_up_amr,
      auth_time: step_up_now.to_time.to_i,
      client_id: step_up_client.client_id,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
      issuer: OidcIssuer.for_client(step_up_client),
      audiences: [step_up_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
    )
    step_up_local_session = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(step_up_client.client_id),
      issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
      sid: step_up_event.public_id, absolute_expires_at: 1.hour.from_now,
    ).session
    raise RuntimeError, "Base ORG Step-Up RP session enrollment failed" unless step_up_local_session

    (@base_browser_rp_credentials ||= {})[[step_up_client.client_id, step_up_token.public_id]] = [
      step_up_access_token, step_up_refresh_token, step_up_local_session.public_id,
    ]
    grants.last.update!(revoked_at: Time.current, revoked_by_operator: @operator, revoke_reason_code: "duty_ended")

    http_headers_5 =
      begin
        rp_headers = as_staff_headers(@approver, host: @host, session_public_id: @approver_token.public_id)
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
            rp_local_session = RpCallbackCommitter.call(
              cell: RpCellBinding.for_client(rp_client.client_id),
              issuer: OidcIssuer.for_client(rp_client),
              subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
              sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
            ).session
            raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

            @base_browser_rp_credentials[rp_key] = [
              rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
            ]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    post(
      base_org_support_app_enforcement_case_approval_url(the_case.public_id, host: @host),
      params: { principal_effect: { access_blocking: true } },
      headers: http_headers_5,
      as: :json,
    )

    assert_response :forbidden
    assert_equal "pending_approval", the_case.reload.state
  end

  test "releasing one blocking case keeps the principal locked while another blocking case is in force" do
    client = @client
    first, second =
      2.times.map do
      the_case = AppEnforcementCase.new(
        kind: "temporary_freeze",
        duration_mode: "timed",
        visibility: "visible",
        release_mode: "operator",
        effective_at: Time.current,
        expires_at: 1.day.from_now,
        reason_code: "security_incident",
        principal_public_id: client.public_id,
        applied_by_operator_public_id: @approver.public_id,
      )
      the_case.build_principal_effect(
        principal_public_id: client.public_id,
        access_blocking: true,
        effective_at: Time.current,
      )
      EnforcementCaseApplyOperation.call(
        enforcement_case: the_case,
        actor_operator_public_id: the_case.applied_by_operator_public_id,
      )
      the_case
    end
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_RELEASE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    step_up_token = @operator_token
    step_up_actor = @operator
    step_up_now = OpBaseOrgRecord.database_now
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.reload
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_acr = StepUpEvidenceResolver::STEP_UP_ACR
    step_up_amr = ["passkey"]
    step_up_event = OpOrgGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch,
      operator_token: step_up_token,
      oidc_client_id: step_up_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(step_up_now.to_time.to_i).utc,
      oidc_acr: step_up_acr,
      oidc_amr: JSON.generate(step_up_amr),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_refresh_token = step_up_event.issue_refresh_token!
    step_up_access_token = AuthenticationTokenService.encode(
      step_up_token.actor_record,
      host: URI.parse(@host).host,
      resource_type: "operator",
      session_public_id: step_up_token.public_id,
      base_session_public_id: step_up_token.public_id,
      oidc_sid: step_up_event.public_id,
      oidc_jti: step_up_event.oidc_jti,
      expires_at: step_up_now + 10.minutes,
      scopes: %w(openid profile),
      acr: step_up_acr,
      amr: step_up_amr,
      auth_time: step_up_now.to_time.to_i,
      client_id: step_up_client.client_id,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
      issuer: OidcIssuer.for_client(step_up_client),
      audiences: [step_up_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
    )
    step_up_local_session = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(step_up_client.client_id),
      issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
      sid: step_up_event.public_id, absolute_expires_at: 1.hour.from_now,
    ).session
    raise RuntimeError, "Base ORG Step-Up RP session enrollment failed" unless step_up_local_session

    (@base_browser_rp_credentials ||= {})[[step_up_client.client_id, step_up_token.public_id]] = [
      step_up_access_token, step_up_refresh_token, step_up_local_session.public_id,
    ]
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
            rp_local_session = RpCallbackCommitter.call(
              cell: RpCellBinding.for_client(rp_client.client_id),
              issuer: OidcIssuer.for_client(rp_client),
              subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
              sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
            ).session
            raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

            @base_browser_rp_credentials[rp_key] = [
              rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
            ]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end

    post(
      base_org_support_app_enforcement_case_release_url(first.public_id, host: @host),
      params: { reason: "revoked" },
      headers: headers,
      as: :json,
    )

    assert_response :ok
    assert_predicate first.reload.ended_at, :present?
    assert_predicate client.reload, :admin_locked?

    replay_headers = headers.dup
    replay_cookie_values =
      replay_headers.fetch("Cookie").split("; ").to_h do |entry|
        entry.split("=", 2)
      end
    response.cookies.each { |name, value| replay_cookie_values[name] = value }
    replay_cookie = replay_cookie_values.map { |name, value| "#{name}=#{value}" }.join("; ")
    replay_headers = replay_headers.merge("Cookie" => replay_cookie, "HTTP_COOKIE" => replay_cookie)
    if replay_cookie_values.key?(AuthenticationBase::ACCESS_COOKIE_KEY)
      replay_headers["Authorization"] = "Bearer #{replay_cookie_values.fetch(AuthenticationBase::ACCESS_COOKIE_KEY)}"
    end
    post(
      base_org_support_app_enforcement_case_release_url(second.public_id, host: @host),
      params: { reason: "revoked" },
      headers: replay_headers,
      as: :json,
    )

    assert_response :ok
    assert_not_predicate client.reload, :admin_locked?
    ended = EnforcementEvent.find_by!(case_public_id: second.public_id, event_type: "ended")

    assert_equal @operator.public_id, ended.operator_public_id
  end

  test "an unknown release reason is refused instead of defaulting" do
    client = @client
    the_case = AppEnforcementCase.new(
      kind: "temporary_freeze",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "security_incident",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: @approver.public_id,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_RELEASE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    step_up_token = @operator_token
    step_up_actor = @operator
    step_up_now = OpBaseOrgRecord.database_now
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.reload
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_acr = StepUpEvidenceResolver::STEP_UP_ACR
    step_up_amr = ["passkey"]
    step_up_event = OpOrgGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch,
      operator_token: step_up_token,
      oidc_client_id: step_up_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(step_up_now.to_time.to_i).utc,
      oidc_acr: step_up_acr,
      oidc_amr: JSON.generate(step_up_amr),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_refresh_token = step_up_event.issue_refresh_token!
    step_up_access_token = AuthenticationTokenService.encode(
      step_up_token.actor_record,
      host: URI.parse(@host).host,
      resource_type: "operator",
      session_public_id: step_up_token.public_id,
      base_session_public_id: step_up_token.public_id,
      oidc_sid: step_up_event.public_id,
      oidc_jti: step_up_event.oidc_jti,
      expires_at: step_up_now + 10.minutes,
      scopes: %w(openid profile),
      acr: step_up_acr,
      amr: step_up_amr,
      auth_time: step_up_now.to_time.to_i,
      client_id: step_up_client.client_id,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
      issuer: OidcIssuer.for_client(step_up_client),
      audiences: [step_up_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
    )
    step_up_local_session = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(step_up_client.client_id),
      issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
      sid: step_up_event.public_id, absolute_expires_at: 1.hour.from_now,
    ).session
    raise RuntimeError, "Base ORG Step-Up RP session enrollment failed" unless step_up_local_session

    (@base_browser_rp_credentials ||= {})[[step_up_client.client_id, step_up_token.public_id]] = [
      step_up_access_token, step_up_refresh_token, step_up_local_session.public_id,
    ]
    ["", "break_glass_released", "appeal_approved", "REVOKED"].each do |reason|
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
                                       session_public_id: rp_token.public_id,
                                       base_session_public_id: rp_token.public_id,
                                       oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                       expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                       subject: OidcSubject.for(
                                         rp_token.actor_record,
                                         resource_type: "operator",
                                       ), client_id: rp_client.client_id,
              )
              rp_local_session = RpCallbackCommitter.call(
                cell: RpCellBinding.for_client(rp_client.client_id),
                issuer: OidcIssuer.for_client(rp_client),
                subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
                sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
              ).session
              raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

              @base_browser_rp_credentials[rp_key] = [
                rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
              ]
            end
            if @base_browser_rp_credentials[rp_key]
              rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
              rp_cookie = [
                rp_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
                "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
              ].join("; ")
              rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
            end
          end
          rp_headers
        end
      post(
        base_org_support_app_enforcement_case_release_url(the_case.public_id, host: @host),
        params: { reason: reason },
        headers: http_headers_4,
        as: :json,
      )

      credential_key = ["base-org-ww", @operator_token.public_id]
      rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(credential_key)
      @base_browser_rp_credentials[credential_key] = [
        response.cookies.fetch(OidcRpBrowserCredentialContract::ACCESS_COOKIE, rp_access),
        response.cookies.fetch(OidcRpBrowserCredentialContract::REFRESH_COOKIE, rp_refresh),
        rp_local_session_public_id,
      ]

      assert_response :unprocessable_content
    end
    assert_nil the_case.reload.ended_at
  end

  test "a permanent ban is not released through the console" do
    client = @client
    the_case = AppEnforcementCase.new(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "visible",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: @approver.public_id,
      approved_by_operator_public_id: @operator.public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: client.public_id,
      access_blocking: true,
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_RELEASE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    step_up_token = @operator_token
    step_up_actor = @operator
    step_up_now = OpBaseOrgRecord.database_now
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.reload
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_acr = StepUpEvidenceResolver::STEP_UP_ACR
    step_up_amr = ["passkey"]
    step_up_event = OpOrgGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch,
      operator_token: step_up_token,
      oidc_client_id: step_up_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(step_up_now.to_time.to_i).utc,
      oidc_acr: step_up_acr,
      oidc_amr: JSON.generate(step_up_amr),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_refresh_token = step_up_event.issue_refresh_token!
    step_up_access_token = AuthenticationTokenService.encode(
      step_up_token.actor_record,
      host: URI.parse(@host).host,
      resource_type: "operator",
      session_public_id: step_up_token.public_id,
      base_session_public_id: step_up_token.public_id,
      oidc_sid: step_up_event.public_id,
      oidc_jti: step_up_event.oidc_jti,
      expires_at: step_up_now + 10.minutes,
      scopes: %w(openid profile),
      acr: step_up_acr,
      amr: step_up_amr,
      auth_time: step_up_now.to_time.to_i,
      client_id: step_up_client.client_id,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
      issuer: OidcIssuer.for_client(step_up_client),
      audiences: [step_up_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
    )
    step_up_local_session = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(step_up_client.client_id),
      issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
      sid: step_up_event.public_id, absolute_expires_at: 1.hour.from_now,
    ).session
    raise RuntimeError, "Base ORG Step-Up RP session enrollment failed" unless step_up_local_session

    (@base_browser_rp_credentials ||= {})[[step_up_client.client_id, step_up_token.public_id]] = [
      step_up_access_token, step_up_refresh_token, step_up_local_session.public_id,
    ]

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
            rp_local_session = RpCallbackCommitter.call(
              cell: RpCellBinding.for_client(rp_client.client_id),
              issuer: OidcIssuer.for_client(rp_client),
              subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
              sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
            ).session
            raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

            @base_browser_rp_credentials[rp_key] = [
              rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
            ]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    post(
      base_org_support_app_enforcement_case_release_url(the_case.public_id, host: @host),
      params: { reason: "revoked" },
      headers: http_headers_3,
      as: :json,
    )

    assert_response :unprocessable_content
    assert_nil the_case.reload.ended_at
    assert_predicate client.reload, :admin_locked?
  end

  test "a separate operator with the review capability rejects an appeal, and the event names them" do
    client = @client
    the_case = AppEnforcementCase.create!(
      kind: "security_lock",
      state: "draft",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "verification_required",
      effective_at: Time.current,
      reason_code: "security_incident",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: @operator.public_id,
    )
    appeal = AppEnforcementAppeal.create!(
      # rubocop:disable I18n/RailsI18n/DecorateString -- appeal statements are stored user content, not UI copy
      enforcement_case: the_case,
      reason_code: "incorrect_decision",
      statement: "Please review this decision.",
      # rubocop:enable I18n/RailsI18n/DecorateString
      submitted_at: Time.current,
    )
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_REVIEW_APPEAL_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @approver,
        granted_by_operator: @operator,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    step_up_token = @approver_token
    step_up_actor = @approver
    step_up_now = OpBaseOrgRecord.database_now
    step_up_token.rotate_refresh_token!(now: step_up_now)
    step_up_token.reload
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_acr = StepUpEvidenceResolver::STEP_UP_ACR
    step_up_amr = ["passkey"]
    step_up_event = OpOrgGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch,
      operator_token: step_up_token,
      oidc_client_id: step_up_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(step_up_now.to_time.to_i).utc,
      oidc_acr: step_up_acr,
      oidc_amr: JSON.generate(step_up_amr),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_refresh_token = step_up_event.issue_refresh_token!
    step_up_access_token = AuthenticationTokenService.encode(
      step_up_token.actor_record,
      host: URI.parse(@host).host,
      resource_type: "operator",
      session_public_id: step_up_token.public_id,
      base_session_public_id: step_up_token.public_id,
      oidc_sid: step_up_event.public_id,
      oidc_jti: step_up_event.oidc_jti,
      expires_at: step_up_now + 10.minutes,
      scopes: %w(openid profile),
      acr: step_up_acr,
      amr: step_up_amr,
      auth_time: step_up_now.to_time.to_i,
      client_id: step_up_client.client_id,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
      issuer: OidcIssuer.for_client(step_up_client),
      audiences: [step_up_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
    )
    step_up_local_session = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(step_up_client.client_id),
      issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
      sid: step_up_event.public_id, absolute_expires_at: 1.hour.from_now,
    ).session
    raise RuntimeError, "Base ORG Step-Up RP session enrollment failed" unless step_up_local_session

    (@base_browser_rp_credentials ||= {})[[step_up_client.client_id, step_up_token.public_id]] = [
      step_up_access_token, step_up_refresh_token, step_up_local_session.public_id,
    ]

    http_headers_2 =
      begin
        rp_headers = as_staff_headers(@approver, host: @host, session_public_id: @approver_token.public_id)
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
            rp_local_session = RpCallbackCommitter.call(
              cell: RpCellBinding.for_client(rp_client.client_id),
              issuer: OidcIssuer.for_client(rp_client),
              subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
              sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
            ).session
            raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

            @base_browser_rp_credentials[rp_key] = [
              rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
            ]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    post(
      base_org_support_app_enforcement_case_appeal_review_url(the_case.public_id, host: @host),
      params: { resolution_code: "rejected" },
      headers: http_headers_2,
      as: :json,
    )

    assert_response :ok
    assert_equal "rejected", appeal.reload.state
    assert_equal @approver.public_id, appeal.reviewer_operator_public_id
    event = EnforcementEvent.find_by!(case_public_id: the_case.public_id, event_type: "appeal_rejected")

    assert_equal @approver.public_id, event.operator_public_id
  end

  test "index scopes strictly to the app realm" do
    app_client = @client
    app_case = AppEnforcementCase.create!(
      kind: "cooldown",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "automatic",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "abuse",
      principal_public_id: app_client.public_id,
      applied_by_operator_public_id: @approver.public_id,
    )
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @approver,
      origin: "grant",
      capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
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
            rp_local_session = RpCallbackCommitter.call(
              cell: RpCellBinding.for_client(rp_client.client_id),
              issuer: OidcIssuer.for_client(rp_client),
              subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
              sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
            ).session
            raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

            @base_browser_rp_credentials[rp_key] = [
              rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
            ]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    get(
      base_org_support_app_enforcement_cases_url(host: @host),
      headers: http_headers_1,
      as: :json,
    )

    assert_response :ok
    public_ids = response.parsed_body.fetch("enforcement_cases").map { |c| c.fetch("public_id") }

    assert_includes public_ids, app_case.public_id
  end

  test "a malformed principal filter is a bad request, not an empty list" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @approver,
      origin: "grant",
      capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

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
            rp_local_session = RpCallbackCommitter.call(
              cell: RpCellBinding.for_client(rp_client.client_id),
              issuer: OidcIssuer.for_client(rp_client),
              subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
              sid: rp_session.public_id, absolute_expires_at: 1.hour.from_now,
            ).session
            raise RuntimeError, "Base ORG RP session enrollment failed" unless rp_local_session

            @base_browser_rp_credentials[rp_key] = [
              rp_access, rp_session.issue_refresh_token!, rp_local_session.public_id,
            ]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh, rp_local_session_public_id = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_public_id)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    get(
      base_org_support_app_enforcement_cases_url(host: @host, principal_public_id: "bad value\u0000"),
      headers: http_headers_0,
      as: :json,
    )

    assert_response :bad_request
  end
end
