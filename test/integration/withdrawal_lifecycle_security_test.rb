# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class WithdrawalLifecycleSecurityTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @user = create_verified_user_with_email(email_address: "withdrawal-p0-#{SecureRandom.hex(4)}@example.com")
    @user.update_columns(created_at: 120.days.ago, updated_at: 120.days.ago)
    @token = ClientToken.create!(
      user: @user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      public_id: "wd#{SecureRandom.hex(8)}",
      discard_at: 1.day.from_now,
      purge_eligible_at: 2.days.from_now,
    )
    @other_token = ClientToken.create!(
      user: @user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      public_id: "wo#{SecureRandom.hex(8)}",
      discard_at: 1.day.from_now,
      purge_eligible_at: 2.days.from_now,
    )
    satisfy_user_verification(@token, scope: "withdrawal")
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
  end

  test "confirmed withdrawal revokes all normal sessions and issues a ceremony session" do
    with_step_up_satisfied do
      freeze_time do
        http_headers_3 =
          begin
            fx0_token = @token
            mark_token_step_up_satisfied_for_test(fx0_token, scope: "withdrawal")
            fx0_headers =
              begin
                f0_headers = as_user_headers(
                  @user,
                  host: @host,
                  headers: browser_headers,
                  session_public_id: fx0_token.public_id,
                )
                f0_host = f0_headers["Host"]
                f0_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{f0_host}/") if f0_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                f0_family, f0_surface = f0_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(f0_family) && f0_surface == "app"
                  f0_client_id =
                    case f0_family
                    when "base" then "base-#{f0_surface}-ww"
                    when "edit" then "edit-org-ww"
                    else "#{f0_family}-#{f0_surface}"
                    end
                  f0_token = ClientToken.find_by!(public_id: f0_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  f0_client = OidcClientRegistry.find!(f0_client_id)
                  f0_key = [f0_client.client_id, f0_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[f0_key] && f0_token.currently_usable? &&
                      !(f0_token.device_session_id && OpAppGrant.exists?(
                        device_session_id: f0_token.device_session_id,
                        oidc_client_id: f0_client.client_id,
                        revoked_at: nil,
                      ))
                    f0_token.rotate_refresh_token! unless f0_token.device_session_record.current_refresh_token_id
                    f0_now = Time.current
                    f0_session = OpAppGrant.create!(
                      client_token: f0_token, oidc_client_id: f0_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f0_now,
                      refresh_token_expires_at: f0_now + 10.minutes,
                    )
                    f0_access = AuthenticationTokenService.encode(
                      f0_token.actor_record,
                      host: f0_host,
                      resource_type: "client",
                      session_public_id: f0_token.public_id,
                      base_session_public_id: f0_token.public_id,
                      oidc_sid: f0_session.public_id,
                      oidc_jti: f0_session.oidc_jti,
                      expires_at: f0_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f0_client),
                      audiences: [f0_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f0_client),
                      subject: OidcSubject.for(
                        f0_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: f0_client.client_id,
                    )
                    @base_browser_rp_credentials[f0_key] =
                      [f0_access, f0_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[f0_key]
                    f0_access, f0_refresh = @base_browser_rp_credentials.fetch(f0_key)
                    f0_cookie = [
                      f0_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f0_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f0_refresh)}",
                    ].join("; ")
                    f0_headers = f0_headers.merge(
                      "Cookie" => f0_cookie,
                      "HTTP_COOKIE" => f0_cookie,
                    )
                  end
                end
                f0_headers
              end
            fx0_headers.merge(
              "Authorization" => "Bearer #{
                    jwt_access_token_for(
                      @user,
                      host: @host,
                      session_public_id: fx0_token.public_id,
                      resource_type: "client",
                    )
                  }",
            )
          end
        patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
              params: { ack_schedule_purge: "1" },
              headers: http_headers_3

        assert_response :see_other
        mark_token_step_up_satisfied_for_test(@token, scope: "withdrawal")
        http_headers_2 =
          begin
            fx1_token = @token
            mark_token_step_up_satisfied_for_test(fx1_token, scope: "withdrawal")
            fx1_headers =
              begin
                f1_headers = as_user_headers(
                  @user,
                  host: @host,
                  headers: browser_headers,
                  session_public_id: fx1_token.public_id,
                )
                f1_host = f1_headers["Host"]
                f1_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{f1_host}/") if f1_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                f1_family, f1_surface = f1_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(f1_family) && f1_surface == "app"
                  f1_client_id =
                    case f1_family
                    when "base" then "base-#{f1_surface}-ww"
                    when "edit" then "edit-org-ww"
                    else "#{f1_family}-#{f1_surface}"
                    end
                  f1_token = ClientToken.find_by!(public_id: f1_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  f1_client = OidcClientRegistry.find!(f1_client_id)
                  f1_key = [f1_client.client_id, f1_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[f1_key] && f1_token.currently_usable? &&
                      !(f1_token.device_session_id && OpAppGrant.exists?(
                        device_session_id: f1_token.device_session_id,
                        oidc_client_id: f1_client.client_id,
                        revoked_at: nil,
                      ))
                    f1_token.rotate_refresh_token! unless f1_token.device_session_record.current_refresh_token_id
                    f1_now = Time.current
                    f1_session = OpAppGrant.create!(
                      client_token: f1_token, oidc_client_id: f1_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f1_now,
                      refresh_token_expires_at: f1_now + 10.minutes,
                    )
                    f1_access = AuthenticationTokenService.encode(
                      f1_token.actor_record,
                      host: f1_host,
                      resource_type: "client",
                      session_public_id: f1_token.public_id,
                      base_session_public_id: f1_token.public_id,
                      oidc_sid: f1_session.public_id,
                      oidc_jti: f1_session.oidc_jti,
                      expires_at: f1_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f1_client),
                      audiences: [f1_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f1_client),
                      subject: OidcSubject.for(
                        f1_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: f1_client.client_id,
                    )
                    @base_browser_rp_credentials[f1_key] =
                      [f1_access, f1_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[f1_key]
                    f1_access, f1_refresh = @base_browser_rp_credentials.fetch(f1_key)
                    f1_cookie = [
                      f1_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f1_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f1_refresh)}",
                    ].join("; ")
                    f1_headers = f1_headers.merge(
                      "Cookie" => f1_cookie,
                      "HTTP_COOKIE" => f1_cookie,
                    )
                  end
                end
                f1_headers
              end
            fx1_headers.merge(
              "Authorization" => "Bearer #{
                    jwt_access_token_for(
                      @user,
                      host: @host,
                      session_public_id: fx1_token.public_id,
                      resource_type: "client",
                    )
                  }",
            )
          end
        patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
              params: { ack_deactivate_today: "1" },
              headers: http_headers_2
      end
    end

    assert_response :see_other

    assert_predicate @token.reload, :revoked?, "current MFA-verified continuation session must be closed"
    assert_predicate @other_token.reload, :revoked?, "other sessions must be revoked once withdrawal is active"
    assert_equal 1, ClientWithdrawalCeremony.where(client: @user).count
    assert_not_nil @user.reload.withdrawal_started_at
    assert_not_nil @user.deactivated_at
  end

  test "withdrawal recovery is rejected before one hour and after purge deadline" do
    with_step_up_satisfied do
      freeze_time do
        http_headers_1 =
          begin
            fx2_token = @token
            mark_token_step_up_satisfied_for_test(fx2_token, scope: "withdrawal")
            fx2_headers =
              begin
                f2_headers = as_user_headers(
                  @user,
                  host: @host,
                  headers: browser_headers,
                  session_public_id: fx2_token.public_id,
                )
                f2_host = f2_headers["Host"]
                f2_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{f2_host}/") if f2_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                f2_family, f2_surface = f2_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(f2_family) && f2_surface == "app"
                  f2_client_id =
                    case f2_family
                    when "base" then "base-#{f2_surface}-ww"
                    when "edit" then "edit-org-ww"
                    else "#{f2_family}-#{f2_surface}"
                    end
                  f2_token = ClientToken.find_by!(public_id: f2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  f2_client = OidcClientRegistry.find!(f2_client_id)
                  f2_key = [f2_client.client_id, f2_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[f2_key] && f2_token.currently_usable? &&
                      !(f2_token.device_session_id && OpAppGrant.exists?(
                        device_session_id: f2_token.device_session_id,
                        oidc_client_id: f2_client.client_id,
                        revoked_at: nil,
                      ))
                    f2_token.rotate_refresh_token! unless f2_token.device_session_record.current_refresh_token_id
                    f2_now = Time.current
                    f2_session = OpAppGrant.create!(
                      client_token: f2_token, oidc_client_id: f2_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f2_now,
                      refresh_token_expires_at: f2_now + 10.minutes,
                    )
                    f2_access = AuthenticationTokenService.encode(
                      f2_token.actor_record,
                      host: f2_host,
                      resource_type: "client",
                      session_public_id: f2_token.public_id,
                      base_session_public_id: f2_token.public_id,
                      oidc_sid: f2_session.public_id,
                      oidc_jti: f2_session.oidc_jti,
                      expires_at: f2_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f2_client),
                      audiences: [f2_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f2_client),
                      subject: OidcSubject.for(
                        f2_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: f2_client.client_id,
                    )
                    @base_browser_rp_credentials[f2_key] =
                      [f2_access, f2_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[f2_key]
                    f2_access, f2_refresh = @base_browser_rp_credentials.fetch(f2_key)
                    f2_cookie = [
                      f2_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f2_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f2_refresh)}",
                    ].join("; ")
                    f2_headers = f2_headers.merge(
                      "Cookie" => f2_cookie,
                      "HTTP_COOKIE" => f2_cookie,
                    )
                  end
                end
                f2_headers
              end
            fx2_headers.merge(
              "Authorization" => "Bearer #{
                    jwt_access_token_for(
                      @user,
                      host: @host,
                      session_public_id: fx2_token.public_id,
                      resource_type: "client",
                    )
                  }",
            )
          end
        patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
              params: { ack_schedule_purge: "1" },
              headers: http_headers_1

        assert_response :see_other
        mark_token_step_up_satisfied_for_test(@token, scope: "withdrawal")
        http_headers_0 =
          begin
            fx3_token = @token
            mark_token_step_up_satisfied_for_test(fx3_token, scope: "withdrawal")
            fx3_headers =
              begin
                f3_headers = as_user_headers(
                  @user,
                  host: @host,
                  headers: browser_headers,
                  session_public_id: fx3_token.public_id,
                )
                f3_host = f3_headers["Host"]
                f3_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{f3_host}/") if f3_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                f3_family, f3_surface = f3_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(f3_family) && f3_surface == "app"
                  f3_client_id =
                    case f3_family
                    when "base" then "base-#{f3_surface}-ww"
                    when "edit" then "edit-org-ww"
                    else "#{f3_family}-#{f3_surface}"
                    end
                  f3_token = ClientToken.find_by!(public_id: f3_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  f3_client = OidcClientRegistry.find!(f3_client_id)
                  f3_key = [f3_client.client_id, f3_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[f3_key] && f3_token.currently_usable? &&
                      !(f3_token.device_session_id && OpAppGrant.exists?(
                        device_session_id: f3_token.device_session_id,
                        oidc_client_id: f3_client.client_id,
                        revoked_at: nil,
                      ))
                    f3_token.rotate_refresh_token! unless f3_token.device_session_record.current_refresh_token_id
                    f3_now = Time.current
                    f3_session = OpAppGrant.create!(
                      client_token: f3_token, oidc_client_id: f3_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f3_now,
                      refresh_token_expires_at: f3_now + 10.minutes,
                    )
                    f3_access = AuthenticationTokenService.encode(
                      f3_token.actor_record,
                      host: f3_host,
                      resource_type: "client",
                      session_public_id: f3_token.public_id,
                      base_session_public_id: f3_token.public_id,
                      oidc_sid: f3_session.public_id,
                      oidc_jti: f3_session.oidc_jti,
                      expires_at: f3_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(f3_client),
                      audiences: [f3_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f3_client),
                      subject: OidcSubject.for(
                        f3_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: f3_client.client_id,
                    )
                    @base_browser_rp_credentials[f3_key] =
                      [f3_access, f3_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[f3_key]
                    f3_access, f3_refresh = @base_browser_rp_credentials.fetch(f3_key)
                    f3_cookie = [
                      f3_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f3_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f3_refresh)}",
                    ].join("; ")
                    f3_headers = f3_headers.merge(
                      "Cookie" => f3_cookie,
                      "HTTP_COOKIE" => f3_cookie,
                    )
                  end
                end
                f3_headers
              end
            fx3_headers.merge(
              "Authorization" => "Bearer #{
                    jwt_access_token_for(
                      @user,
                      host: @host,
                      session_public_id: fx3_token.public_id,
                      resource_type: "client",
                    )
                  }",
            )
          end
        patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
              params: { ack_deactivate_today: "1" },
              headers: http_headers_0
        ceremony = ClientWithdrawalCeremony.where(client: @user).order(created_at: :desc).first
        ceremony_cookie = {
          "Cookie" => "#{withdrawal_ceremony_cookie_name}=#{cookies[withdrawal_ceremony_cookie_name]}",
        }

        assert_equal ceremony.public_id, cookies[withdrawal_ceremony_cookie_name].to_s.split(":", 2).first

        travel 10.minutes
        post base_app_identity_withdrawal_url(ri: "jp", host: @host), headers: browser_headers.merge(ceremony_cookie)

        assert_response :see_other
        assert_not_nil @user.reload.deactivated_at

        @user.update_columns(deactivated_at: 31.days.ago, discard_at: 31.days.ago, purge_eligible_at: 1.minute.ago)
        post base_app_identity_withdrawal_url(ri: "jp", host: @host), headers: browser_headers.merge(ceremony_cookie)

        assert_response :see_other
        assert_not_nil @user.reload.deactivated_at
      end
    end
  end

  private

  def with_step_up_satisfied(&)
    satisfied = Actor::StepUp.new(
      scope: "withdrawal",
      required_aal: :aal2,
      allowed_methods: %i(totp passkey),
      satisfied: true,
      satisfied_at: Time.current,
      expires_at: 15.minutes.from_now,
      usable_token: true,
      method: "passkey",
      session_bound: true,
      token_bound: true,
      purpose: "step_up",
      audience: "step_up:app",
      purpose_bound: true,
      audience_bound: true,
      phishing_resistant_required: true,
      user_verification_required: true,
      full_reauthentication_required: false,
      resource_bound: true,
      tenant_bound: true,
    )
    StepUpResolver.stub(:call, satisfied, &)
  end

  def withdrawal_ceremony_cookie_name
    AuthenticationCookieName.with_host_prefix("withdrawal_ceremony", production: JitSessionCookieConfig.force_secure?)
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class WithdrawalLifecycleSecurityTest
  private
end

# DAMP local helper copy for former shared test support.
class WithdrawalLifecycleSecurityTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    base_hosts = {
      "APP" => ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      "ORG" => ENV.fetch("PUBLIC_BASE_STAFF_URL"),
      "COM" => ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
    }
    return "surface:BASE_#{base_hosts.key(normalized)}" if base_hosts.value?(normalized)

    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :app),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def insert_verified_visitor_email!(visitor_id:, address:)
    VisitorEmail.insert_all(
      [
        {
          visitor_id: visitor_id,
          address: address,
          address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :com),
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          otp_attempts_count: 0,
          public_id: SecureRandom.alphanumeric(21),
          created_at: Time.current,
          updated_at: Time.current,
        },
      ],
    )
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_visitor_verification(token, scope: nil)
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    when "VisitorToken" then "step_up:com"
    else "step_up:app"
    end
  end

  def signed_step_up_pt_for(path, surface:, session_nonce:)
    safe_path = path.to_s
    return nil if safe_path.blank? || !safe_path.start_with?("/") || safe_path.match?(/[\x00-\x1F\x7F]/)

    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256",
      serializer: JSON,
      url_safe: true,
    )
    verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => surface.to_s,
        "session_nonce" => session_nonce.to_s,
        "pt" => safe_path, },
      purpose: :path_target,
      expires_in: 15.minutes,
    )
  end

  def signed_step_up_grant_for(actor:, token:, scope:, return_to:, surface:, methods: %i(email_otp totp passkey),
                               aal: "aal2")
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface.to_s,
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      required_scope: scope.to_s,
      required_aal: aal,
      allowed_methods: methods,
      return_to: return_to,
      expires_at: 15.minutes.from_now,
    ).grant
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def csrf_headers(token)
    { "X-CSRF-Token" => token }
  end

  def fetch_csrf_token(path)
    get(path)
    response.body[/name="authenticity_token" value="([^"]+)"/, 1] || response.body
  end

  def social_callback_headers(host)
    scheme = host.to_s.include?("localhost") ? "http" : "https"
    origin = "#{scheme}://#{host}"
    cookies["csrf_token"] = csrf_token_value if respond_to?(:cookies)
    {
      "Host" => host,
      "Origin" => origin,
      "Referer" => "#{origin}/",
      "Sec-Fetch-Site" => "same-origin",
      "X-STRICT-SOCIAL-STATE" => "1",
      "X-CSRF-Token" => csrf_token_value,
    }
  end

  def social_auth_state_from_response
    session[:social_auth_state].presence || begin
      uri = URI.parse(response.location.to_s)
      Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
    rescue URI::InvalidURIError
      nil
    end
  end

  def seed_social_auth_session(provider:, intent: "login", user: nil, entry: nil, ri: "jp", rt: nil, referer: nil)
    host = configured_host(:sign_service)
    host!(host) if respond_to?(:host!)
    normalized_provider = SocialIdentifiable.normalize_provider(provider)
    continue_path =
      if intent.to_s == "link"
        public_send(:"auth_app_settings_#{normalized_provider}_path", ri: ri)
      elsif entry.to_s == "sign_up"
        public_send(:"auth_app_social_#{normalized_provider}_registration_path", ri: ri, rt: rt)
      else
        public_send(:"auth_app_social_#{normalized_provider}_session_path", ri: ri, rt: rt)
      end
    headers = social_callback_headers(host)
    headers["Referer"] = referer if referer.present?
    if user
      user_headers =
        as_user_headers(user, host: host)
      token = ClientToken.find_by(public_id: user_headers["X-TEST-SESSION-PUBLIC-ID"])
      mark_token_step_up_satisfied_for_test(
        token,
        scope: SocialAuth::SOCIAL_LINK_SCOPE,
      ) if intent.to_s == "link" && token
      headers = headers.merge(user_headers)
    end
    post(continue_path, headers: headers)
    social_auth_state_from_response
  end

  def assert_oidc_authorize_redirect(location, host:, client_id: "base-rails-rp")
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal client_id, query["client_id"]
    assert_predicate query["state"], :present?
  end
end

# DAMP local helper copy on the test class.
class WithdrawalLifecycleSecurityTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def with_preference_jwt_keys(host: nil)
    audiences = host ? [host] : PreferenceJwtConfiguration.audiences
    pub_key_for_stub = ->(_kid, **_options) { self.class::PREFERENCE_JWT_KEY }
    PreferenceJwtConfiguration.stub(:private_key, self.class::PREFERENCE_JWT_KEY) do
      PreferenceJwtConfiguration.stub(:public_key, self.class::PREFERENCE_JWT_KEY) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, self.class::PREFERENCE_JWT_KEY) do
          PreferenceJwtConfiguration.stub(:public_key_for, pub_key_for_stub) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, audiences) { yield }
              end
            end
          end
        end
      end
    end
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    host_headers.merge("X-CSRF-Token" => csrf_token)
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address, realm: :com),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(AUTH_APP AUTH_ORG AUTH_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google_app] =
      OmniAuth::AuthHash.new(
        provider: "google_app", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end
