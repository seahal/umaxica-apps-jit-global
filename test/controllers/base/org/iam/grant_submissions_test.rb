# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/operator-capability-authorization.md, IAM: the grant screen and the input contract of a grant
# submission (ticket id, operation id, idempotency). Every test states the grants it relies on.
class Base::Org::Iam::GrantSubmissionsTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @granter = operators(:one)
    @grantee = operators(:two)
    @granter_token = OperatorToken.create!(
      staff: @granter,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    # The compliance row normally comes from migration 20260926130000 (365 days, decided 2026-09-26);
    # a schema-only load skips that insert, so the test ensures it with the same value.
    ChronicleRetentionPolicy.find_or_create_by!(code: "compliance") do |policy|
      policy.name = "Compliance"
      policy.duration_days = 365
      policy.permanent = false
    end
  end

  test "with Step-Up the grant screen offers only the non-IAM capabilities the granter holds" do
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_GRANT].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @granter, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    OperatorCapabilityGrant.create!(
      operator: @granter, granted_by_operator: @grantee, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    @granter_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "operator_capability",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
      last_step_up_session_public_id: @granter_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    headers =
      begin
        rp_headers = as_staff_headers(@granter, host: @host, session_public_id: @granter_token.public_id)
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

    get new_base_org_iam_grant_url(ri: "jp", host: @host), headers: headers

    assert_response :ok
    assert_equal "base/org/iam/grants/new", inertia_component
    capability_field = inertia_props.fetch("fields").find { |field| field.fetch("name") == "capability" }

    assert_equal [OperatorCapabilityGrant::SUPPORT_CONSOLE_READ],
                 capability_field.fetch("options").map { |option| option.fetch("value") }

    get base_org_iam_grants_url(ri: "jp", host: @host), headers: headers

    assert_equal [new_base_org_iam_grant_path(ri: "jp")],
                 inertia_props.fetch("actions").map { |action| action.fetch("href") }
  end

  test "ticket ids are accepted up to 64 characters and refused at 65 or with a leading symbol" do
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_GRANT].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @granter, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    OperatorCapabilityGrant.create!(
      operator: @granter, granted_by_operator: @grantee, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    @granter_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "operator_capability",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
      last_step_up_session_public_id: @granter_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    headers =
      begin
        rp_headers = as_staff_headers(@granter, host: @host, session_public_id: @granter_token.public_id)
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
    valid = { operator_public_id: @grantee.public_id,
              capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
              reason_code: "duty_assignment",
              duration_days: "30", }

    ["A" * 65, "-OPS-1"].each do |ticket_id|
      assert_no_difference -> { OperatorCapabilityGrant.count } do
        post base_org_iam_grants_url(host: @host),
             params: valid.merge(ticket_id: ticket_id, operation_id: SecureRandom.uuid), headers: headers
      end

      assert_response :unprocessable_content, "expected ticket id #{ticket_id.inspect} to be refused"
      assert_predicate inertia_props.dig("errors", "ticket_id"), :present?
    end

    ticket_id = "A" * 64
    post base_org_iam_grants_url(host: @host),
         params: valid.merge(ticket_id: ticket_id, operation_id: SecureRandom.uuid), headers: headers

    assert_response :see_other
    assert_equal ticket_id, OperatorCapabilityGrant.find_by!(operator: @grantee).ticket_id
  end

  test "a missing or non-UUIDv4 operation id is refused before anything is granted" do
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_GRANT].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @granter, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    OperatorCapabilityGrant.create!(
      operator: @granter, granted_by_operator: @grantee, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    @granter_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "operator_capability",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
      last_step_up_session_public_id: @granter_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    valid = { operator_public_id: @grantee.public_id,
              capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
              reason_code: "duty_assignment",
              duration_days: "30", }

    [{}, { operation_id: "" }, { operation_id: "00000000-0000-1000-8000-000000000000" }].each do |operation|
      assert_no_difference -> { OperatorCapabilityGrant.count } do
        http_headers_0 =
          begin
            rp_headers = as_staff_headers(@granter, host: @host, session_public_id: @granter_token.public_id)
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
                    device_session_id: rp_token.device_session_id,
                    oidc_client_id: rp_client.client_id,
                    revoked_at: nil,
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
        post base_org_iam_grants_url(host: @host),
             params: valid.merge(operation),
             headers: http_headers_0
      end

      assert_response :unprocessable_content, "expected #{operation.inspect} to be refused"
      assert_predicate inertia_props.dig("errors", "operation_id"), :present?
    end
  end

  test "an operation id reused for a different grant is a conflict and grants nothing more" do
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_GRANT].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @granter, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    OperatorCapabilityGrant.create!(
      operator: @granter, granted_by_operator: @grantee, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    @granter_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "operator_capability",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
      last_step_up_session_public_id: @granter_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    headers =
      begin
        rp_headers = as_staff_headers(@granter, host: @host, session_public_id: @granter_token.public_id)
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
    operation_id = SecureRandom.uuid
    valid = { operator_public_id: @grantee.public_id,
              capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
              duration_days: "30",
              operation_id: operation_id, }

    post base_org_iam_grants_url(host: @host), params: valid.merge(reason_code: "duty_assignment"), headers: headers

    assert_response :see_other

    assert_no_difference -> { OperatorCapabilityGrant.count } do
      post base_org_iam_grants_url(host: @host), params: valid.merge(reason_code: "incident_response"),
                                                 headers: headers
    end

    assert_response :conflict
    assert_predicate inertia_props.dig("errors", "operation_id"), :present?
  end
end
