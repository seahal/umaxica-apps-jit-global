# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Controller-level behavior for social-link completion compatibility.
#
# The Sign callback for app settings social link is the durable authority. These tests pin that:
#   - Sign performs the final link commit
#   - Sign does not emit a Base completion form for link
#   - malformed Base completion posts do not commit
#   - com/org sign surfaces expose no social link routes at all
class BaseSocialLinkCompletionTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @callback_headers = social_callback_headers(@host)
  end

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
  end

  test "sign callback stages the social link until the Auth receiver POST" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "linkcompl_#{SecureRandom.hex(4)}")
    uid = "completion_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: uid, token: "completion_token")

    grant_session =
      begin
        fx0_provider = "google"
        fx0_user = user
        fx0_ri = "jp"
        fx0_host = @host
        host!(fx0_host) if respond_to?(:host!)

        fx0_user_headers =
          begin
            f0_headers =
              begin
                rp_headers = as_user_headers(fx0_user, host: fx0_host)
                rp_host = rp_headers["Host"]
                rp_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(rp_family) && rp_surface == "app"
                  rp_client_id =
                    case rp_family
                    when "base" then "base-#{rp_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{rp_family}-#{rp_surface}"
                    end
                  rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rp_client = OidcClientRegistry.find!(rp_client_id)
                  rp_key = [rp_client.client_id, rp_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                      !(rp_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: rp_token.device_session_id,
                        oidc_client_id: rp_client.client_id,
                        revoked_at: nil,
                      ))
                    rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                    rp_now = Time.current
                    rp_session = ClientRpSession.create!(
                      client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                      refresh_token_expires_at: rp_now + 10.minutes,
                    )
                    rp_access = AuthenticationTokenService.encode(
                      rp_token.actor_record, host: rp_host, resource_type: "client",
                                             session_public_id: rp_token.public_id,
                                             base_session_public_id: rp_token.public_id,
                                             oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                             expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                             issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                             subject: OidcSubject.for(
                                               rp_token.actor_record,
                                               resource_type: "client",
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
                when "edit" then "edit-org"
                else "#{f0_family}-#{f0_surface}"
                end
              f0_token = ClientToken.find_by!(public_id: f0_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f0_client = OidcClientRegistry.find!(f0_client_id)
              f0_key = [f0_client.client_id, f0_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f0_key] && f0_token.currently_usable? &&
                  !(f0_token.device_session_id && ClientRpSession.exists?(
                    device_session_id: f0_token.device_session_id,
                    oidc_client_id: f0_client.client_id,
                    revoked_at: nil,
                  ))
                f0_token.rotate_refresh_token! unless f0_token.device_session_record.current_refresh_token_id
                f0_now = Time.current
                f0_session = ClientRpSession.create!(
                  client_token: f0_token, oidc_client_id: f0_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f0_now,
                  refresh_token_expires_at: f0_now + 10.minutes,
                )
                f0_access = AuthenticationTokenService.encode(
                  f0_token.actor_record, host: f0_host, resource_type: "client",
                                         session_public_id: f0_token.public_id,
                                         base_session_public_id: f0_token.public_id,
                                         oidc_sid: f0_session.public_id, oidc_jti: f0_session.oidc_jti,
                                         expires_at: f0_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f0_client), audiences: [f0_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f0_client),
                                         subject: OidcSubject.for(
                                           f0_token.actor_record,
                                           resource_type: "client",
                                         ), client_id: f0_client.client_id,
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
        fx0_token_public_id = fx0_user_headers.fetch("X-TEST-SESSION-PUBLIC-ID")
        fx0_token = ClientToken.find_by(public_id: fx0_token_public_id)
        fx0_session_public_id = fx0_token&.device_session_record&.public_id.presence || fx0_token_public_id
        mark_token_step_up_satisfied_for_test(
          fx0_token,
          scope: SocialAuth::SOCIAL_LINK_SCOPE,
        ) if fx0_token

        fx0_issuance = IdentitySocialCeremonyGrantIssuer.issue!(
          surface: "app",
          actor_ref: fx0_user.public_id,
          session_ref: fx0_session_public_id,
          operation: "link",
          provider: fx0_provider,
        )

        fx0_normalized_provider = SocialIdentifiable.normalize_provider(fx0_provider)
        fx0_continue_path = public_send(
          :"auth_app_settings_#{fx0_normalized_provider}_path",
          ri: fx0_ri,
          social_ceremony_grant: fx0_issuance.grant,
        )

        fx0_headers = social_callback_headers(fx0_host).merge(fx0_user_headers)
        post(fx0_continue_path, headers: fx0_headers)
        fx0_rails_cookie_key = Rails.application.config.session_options.fetch(:key)
        fx0_rails_cookie = response.cookies.fetch(fx0_rails_cookie_key)
        fx0_user_headers["Cookie"] = [
          fx0_user_headers.fetch("Cookie"),
          "#{fx0_rails_cookie_key}=#{Rack::Utils.escape(fx0_rails_cookie)}",
        ].join("; ")
        fx0_user_headers["HTTP_COOKIE"] = fx0_user_headers.fetch("Cookie")

        Struct.new(:state, :user_headers, :session_public_id, :transaction_id, keyword_init: true).new(
          state: social_auth_state_from_response,
          user_headers: fx0_user_headers,
          session_public_id: fx0_session_public_id,
          transaction_id: fx0_issuance.transaction.transaction_id,
        )
      end

    assert_no_difference("ClientGoogleIdentity.count") do
      get auth_app_social_google_callback_url(ri: "jp"),
          params: { state: grant_session.state }, headers: @callback_headers.merge(grant_session.user_headers)
    end
    assert_response :success
    form = response.parsed_body.at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    cookie_key = Rails.application.config.session_options.fetch(:key)
    grant_session.user_headers["Cookie"] = [grant_session.user_headers.fetch("Cookie").split("; ").reject { |pair|
      pair.start_with?("#{cookie_key}=")
    }.join("; "), "#{cookie_key}=#{Rack::Utils.escape(response.cookies.fetch(cookie_key))}",].join("; ")
    grant_session.user_headers["HTTP_COOKIE"] = grant_session.user_headers.fetch("Cookie")
    assert_difference("ClientGoogleIdentity.count", 1) do
      post form["action"], params: fields, headers: @callback_headers.merge(grant_session.user_headers)

      assert_response :see_other
    end
    assert_redirected_to auth_app_settings_path(ri: "jp")
    assert_not_includes response.body.to_s, "social-completion-form"
    identity = ClientGoogleIdentity.find_by!(uid: uid)

    assert_equal user.id, identity.user_id
    assert_not_respond_to identity, :token
    grant = ClientSocialCeremonyTransaction.find_by!(transaction_id: grant_session.transaction_id)

    assert_operator grant.expires_at, :<=, ClientSocialCeremonyTransaction.database_now
  end

  test "base completion rejects a malformed social result without committing" do
    assert_no_difference("ClientGoogleIdentity.count") do
      assert_no_difference("ClientOidcAuthorizationTransaction.count") do
        post base_app_social_authentication_completion_url(id: "google", ri: "jp", host: @base_host),
             params: { social_ceremony_result: "not-a-real-token", ri: "jp" },
             headers: social_completion_browser_headers
      end
    end

    assert_response :unprocessable_content
    assert_nil response.location
    assert_equal I18n.t("sign.app.social.sessions.create.failure"), response.body
  end

  test "base social login continuation returns to passive Base admission without a provider grant" do
    assert_no_difference(["Client.count", "ClientToken.count", "ClientSocialCeremonyTransaction.count"]) do
      post base_app_social_authentication_continuation_url(id: "google", ri: "jp", host: @base_host),
           headers: { "Host" => @base_host }
    end

    assert_response :see_other
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query)

    assert_equal @base_host, location.host
    assert_equal "/sign", location.path
    assert_equal({ "ri" => "jp" }, query)
    assert_nil session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]
  end

  test "sign com and org surfaces expose no social routes" do
    # The app surface owns the social login route helper...
    assert_respond_to self, :auth_app_social_google_session_path

    # ...while com/org sign surfaces expose no social authentication route at all.
    %w(com org).each do |surface|
      assert_not respond_to?("continue_sign_#{surface}_social_authentication_path"),
                 "sign/#{surface} must not expose a social authentication route helper"
    end
  end

  private

  def social_completion_browser_headers
    {
      "Host" => @base_host,
      "Origin" => "null",
      "Sec-Fetch-Site" => "same-site",
    }
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class BaseSocialLinkCompletionTest
  private
end

# DAMP local helper copy for former shared test support.
class BaseSocialLinkCompletionTest
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

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    _, scope = at, scope || SocialAuth::SOCIAL_LINK_SCOPE
    actor = token.actor_record
    token.rotate_refresh_token! unless token.device_session_record&.current_refresh_token_id
    credential = actor.client_totp_credentials.find_by(
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    ) || ClientTotpCredential.create_for_user!(
      user: actor, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    requirement = StepUpRequirement.new(
      step_up_required: true, scope: scope, allowed_methods: [:totp],
      phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
      ttl: 15.minutes, purpose: "step_up", audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement,
      return_to: (scope == "settings_email") ? "/identity/emails" : "/settings/google",
      base_browser_nonce: nonce, base_token: token,
    )
    transaction = issuance.transaction
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    digest = AuthAdmissionBinding.browser_digest(surface: "app", entry_ref: issuance.reference, nonce: nonce)
    binding.confirm_base!(base_token: token, browser_digest: digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "step_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    # This fixture exercises Social authorization; TOTP code verification has its own public-boundary tests.
    transaction.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: transaction.class.database_now, verified_credential_ref: credential.public_id,
    )
    proof = BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction, ceremony_session_ref: admitted.id.to_s)
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: actor, token: token, transaction: transaction, requirement: requirement, result_reference: proof.reference,
    )
    token.reload
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

  def assert_oidc_authorize_redirect(location, host:, client_id: "base-rails-rp")
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal client_id, query["client_id"]
    assert_predicate query["state"], :present?
  end
end

# DAMP local social completion helpers for former shared test support.
class BaseSocialLinkCompletionTest
  private

  def submit_social_completion_if_present!
    target = URI.parse(response.location) if response.redirect?
    continuation = target&.path == "/social/authentication/completion"
    if continuation
      host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      host!(host)
      https!
      headers = { "Host" => host, "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
      get(target.request_uri, headers: headers)
      form = response.parsed_body.at_css("form")
      raise StandardError, "social completion continuation form missing" unless form

    else
      return unless response.media_type == "text/html" && response.body.include?("social-completion-form")

      assert_forms_submittable_under_policy
      form = response.parsed_body.at_css("form#social-completion-form")
      raise StandardError, "social completion form missing" unless form

      headers = {
        "Host" => URI.parse(form["action"]).host,
        "Origin" => "https://#{configured_host(:sign_service)}",
        "Sec-Fetch-Site" => "same-site",
      }
    end
    params = form.css("input").filter_map do |input|
      name = input["name"]
      [name, input["value"]] if continuation ? !name.nil? : name.present?
    end.to_h
    post(form["action"], params: params, headers: headers)
    cookies.to_hash.each_key { |key| cookies.delete(key) } unless continuation
  end
end

# DAMP local helper copy on the test class.
class BaseSocialLinkCompletionTest
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

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com", token: "google_token")
    OmniAuth.config.mock_auth[:google] =
      OmniAuth::AuthHash.new(
        provider: "google", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: token, refresh_token: "refresh_#{token}", expires_at: 1.hour.from_now.to_i },
      )
  end
end
