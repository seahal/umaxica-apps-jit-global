# typed: false
# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# adr/operator-capability-authorization.md, Access lock and Enforcement: what an approval leaves
# behind when it fails at each point, and who each enforcement event names. Operator A opens, B
# approves, C releases or reviews; every event must name the operator who performed it.
class Base::Org::Support::EnforcementApprovalFailuresTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @operator_a = operators(:one)
    @operator_b = operators(:two)
    @operator_c = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    OperatorPasskeyTestSupport.give_two_active_passkeys!(@operator_c)
    @client = clients(:one)
    @tokens =
      [@operator_a, @operator_b, @operator_c].to_h do |operator|
        token = OperatorToken.create!(
          authentication_epoch: 0,
          staff_id: operator.id, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
          staff_token_status_id: OperatorTokenStatus::ACTIVE,
          staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
          staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
        )
        [operator, token]
      end
    # Step-Up state is written directly here; test/integration/org_admin_step_up_ceremony_test.rb
    # covers the real ceremony. Each operator holds exactly the capability it uses.
    {
      @operator_a => [OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP, "enforcement_case_apply"],
      @operator_b => [OperatorCapabilityGrant::ENFORCEMENT_APPROVE_APP, "enforcement_case_approve"],
      @operator_c => [OperatorCapabilityGrant::ENFORCEMENT_RELEASE_APP, "enforcement_case_release"],
    }.each do |operator, (capability, scope)|
      [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, capability].each do |granted|
        OperatorCapabilityGrant.create!(
          operator: operator, origin: "bootstrap", capability: granted,
          reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
        )
      end
      token = @tokens.fetch(operator)
      token.update_columns(
        last_step_up_at: Time.current, last_step_up_scope: scope, last_step_up_aal: "aal2",
        last_step_up_method: "passkey",
        last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
        last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
        last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:org",
      )
    end
    @pending = AppEnforcementCase.create!(
      kind: "permanent_ban", duration_mode: "permanent", visibility: "hidden", release_mode: "break_glass_only",
      effective_at: Time.current, reason_code: "abuse", principal_public_id: @client.public_id,
      applied_by_operator_public_id: @operator_a.public_id, state: "pending_approval",
    )
  end

  test "failure before the claim: a case that is not pending is refused and left unchanged" do
    @pending.update_columns(state: "failed")

    http_headers_6 =
      begin
        rp_headers = as_staff_headers(
          @operator_b, host: @host,
                       session_public_id: @tokens.fetch(@operator_b).public_id,
        )
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
    post base_org_support_app_enforcement_case_approval_url(@pending.public_id, host: @host),
         params: { principal_effect: { access_blocking: true } },
         headers: http_headers_6,
         as: :json

    assert_response :conflict
    assert_nil @pending.reload.approved_by_operator_public_id
  end

  test "failure after the claim but before the apply starts releases the claim" do
    fails_before_start = ->(**) { raise ArgumentError, "apply did not start" }

    EnforcementCaseApplyOperation.stub(:call, fails_before_start) do
      http_headers_5 =
        begin
          rp_headers = as_staff_headers(
            @operator_b, host: @host,
                         session_public_id: @tokens.fetch(@operator_b).public_id,
          )
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
                  device_session_id: rp_token.device_session_id,
                  oidc_client_id: rp_client.client_id,
                  revoked_at: nil,
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
      post base_org_support_app_enforcement_case_approval_url(@pending.public_id, host: @host),
           params: { principal_effect: { access_blocking: true } },
           headers: http_headers_5,
           as: :json
    end

    assert_response :unprocessable_content
    @pending.reload

    assert_equal "pending_approval", @pending.state
    assert_nil @pending.approved_by_operator_public_id
    assert_not_predicate @client.reload, :admin_locked?
    assert_not EnforcementEvent.exists?(case_public_id: @pending.public_id)
  end

  test "failure while persisting effects rolls the apply back entirely and releases the claim" do
    http_headers_4 =
      begin
        rp_headers = as_staff_headers(
          @operator_b, host: @host,
                       session_public_id: @tokens.fetch(@operator_b).public_id,
        )
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
    post base_org_support_app_enforcement_case_approval_url(@pending.public_id, host: @host),
         params: {
           principal_effect: { access_blocking: true },
           authentication_method_effect: { authentication_method: "not-a-method", effect: "unusable" },
         },
         headers: http_headers_4,
         as: :json

    assert_response :unprocessable_content
    @pending.reload

    assert_equal "pending_approval", @pending.state
    assert_nil @pending.approved_by_operator_public_id
    assert_not_predicate @client.reload, :admin_locked?
    assert_nil @pending.principal_effect_record, "the effect rows rolled back with the state change"
    assert_not EnforcementEvent.exists?(case_public_id: @pending.public_id)
  end

  test "failure in the lock after the state change commits marks the Case failed and keeps the approver" do
    lock_fails = ->(**) { raise ActiveRecord::RecordInvalid, Client.new(security_mode_id: SecurityModeConfigurable::NORMAL) }

    AdministrativeAccessLock.stub(:lock!, lock_fails) do
      http_headers_3 =
        begin
          rp_headers = as_staff_headers(
            @operator_b, host: @host,
                         session_public_id: @tokens.fetch(@operator_b).public_id,
          )
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
                  device_session_id: rp_token.device_session_id,
                  oidc_client_id: rp_client.client_id,
                  revoked_at: nil,
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
      post base_org_support_app_enforcement_case_approval_url(@pending.public_id, host: @host),
           params: { principal_effect: { access_blocking: true } },
           headers: http_headers_3,
           as: :json
    end

    assert_response :unprocessable_content
    @pending.reload

    assert_equal "failed", @pending.state, "a Case whose apply started is never returned to pending"
    assert_equal @operator_b.public_id, @pending.approved_by_operator_public_id
  end

  test "failure after the lock took effect keeps the lock and the approver, and reconciliation writes both events" do
    audit_down = ->(**) { raise ActiveRecord::ConnectionNotEstablished, "chronicle unavailable" }

    EnforcementEvent.stub(:create!, audit_down) do
      http_headers_2 =
        begin
          rp_headers = as_staff_headers(
            @operator_b, host: @host,
                         session_public_id: @tokens.fetch(@operator_b).public_id,
          )
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
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        post(
          base_org_support_app_enforcement_case_approval_url(@pending.public_id, host: @host),
          params: { principal_effect: { access_blocking: true } },
          headers: http_headers_2,
          as: :json,
        )
      end
    end
    @pending.reload

    assert_equal "active", @pending.state
    assert_equal @operator_b.public_id, @pending.approved_by_operator_public_id
    assert_predicate @client.reload, :admin_locked?, "an applied lock is never undone to look pending"
    assert_nil @pending.audited_at

    EnforcementReconciliationJob.perform_now

    approved = EnforcementEvent.find_by!(case_public_id: @pending.public_id, event_type: "approved")

    assert_equal @operator_b.public_id, approved.operator_public_id
    assert EnforcementEvent.exists?(case_public_id: @pending.public_id, event_type: "revocation_reconciled")
  end

  test "each event names the operator who performed it: A opens, B approves and applies, C releases" do
    cooldown_case = AppEnforcementCase.new(
      kind: "temporary_freeze", duration_mode: "timed", visibility: "visible", release_mode: "operator",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: @client.public_id, applied_by_operator_public_id: @operator_a.public_id,
    )
    cooldown_case.build_principal_effect(
      principal_public_id: @client.public_id, access_blocking: true,
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(enforcement_case: cooldown_case, actor_operator_public_id: @operator_a.public_id)

    http_headers_1 =
      begin
        rp_headers = as_staff_headers(
          @operator_b, host: @host,
                       session_public_id: @tokens.fetch(@operator_b).public_id,
        )
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
    post base_org_support_app_enforcement_case_approval_url(@pending.public_id, host: @host),
         params: { principal_effect: { access_blocking: true } },
         headers: http_headers_1,
         as: :json

    assert_response :ok

    http_headers_0 =
      begin
        rp_headers = as_staff_headers(
          @operator_c, host: @host,
                       session_public_id: @tokens.fetch(@operator_c).public_id,
        )
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
    post base_org_support_app_enforcement_case_release_url(cooldown_case.public_id, host: @host),
         params: { reason: "revoked" },
         headers: http_headers_0,
         as: :json

    assert_response :ok
    actors = EnforcementEvent.where(case_public_id: [@pending.public_id, cooldown_case.public_id])
      .pluck(:case_public_id, :event_type, :operator_public_id)

    assert_includes actors, [cooldown_case.public_id, "applied", @operator_a.public_id]
    assert_includes actors, [@pending.public_id, "approved", @operator_b.public_id]
    assert_includes actors, [@pending.public_id, "applied", @operator_b.public_id]
    assert_includes actors, [cooldown_case.public_id, "ended", @operator_c.public_id]
    assert_equal @operator_a.public_id, @pending.reload.applied_by_operator_public_id,
                 "the Case's own attribution still names the opener"
  end

  test "an appeal decision names the reviewer, not the opener or approver" do
    the_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: @client.public_id, applied_by_operator_public_id: @operator_a.public_id,
    )
    appeal = AppEnforcementAppeal.create!(
      # rubocop:disable I18n/RailsI18n/DecorateString -- appeal statements are stored user content, not UI copy
      enforcement_case: the_case, reason_code: "incorrect_decision", statement: "Please review.",
      # rubocop:enable I18n/RailsI18n/DecorateString
      submitted_at: Time.current,
    )

    appeal.resolve!(reviewer_operator_public_id: @operator_c.public_id, resolution_code: "rejected")

    event = EnforcementEvent.find_by!(case_public_id: the_case.public_id, event_type: "appeal_rejected")

    assert_equal @operator_c.public_id, event.operator_public_id
  end
end
