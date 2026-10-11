# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SocialAuthAppFlowContractTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses, :client_email_statuses, :client_totp_credential_statuses,
           :client_secret_credential_statuses

  PROVIDERS = {
    google: {
      provider: "google",
      normalized: "google",
      model: ClientExternalIdentity,
      config_path: :auth_app_settings_path,
      token_prefix: "google",
    },
    apple: {
      provider: "apple",
      normalized: "apple",
      model: ClientExternalIdentity,
      config_path: :auth_app_settings_apple_path,
      token_prefix: "apple",
    },
  }.freeze

  setup do
    OmniAuth.config.test_mode = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.enabled = true
    # The ceremony runs on the Auth host the application is configured with: a request
    # made to any other host gets a session cookie the application does not read back,
    # so the sign-up ticket is lost and the flow restarts instead of advancing.
    @host = configured_host(:sign_service)
    @base_host = ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost")
    @callback_headers = social_callback_headers(@host)
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    TurnstileVerifierStub.enabled = false
  end

  test "Google sign up entry creates one client and one active social identity without email" do
    assert_social_signup_contract(PROVIDERS.fetch(:google))
  end

  test "Apple sign up entry creates one client and one active social identity without email" do
    assert_social_signup_contract(PROVIDERS.fetch(:apple))
  end

  test "Google sign in reuses existing social identity and refreshes credentials" do
    assert_social_sign_in_contract(PROVIDERS.fetch(:google))
  end

  test "Apple sign in reuses existing social identity and refreshes credentials" do
    assert_social_sign_in_contract(PROVIDERS.fetch(:apple))
  end

  test "Google settings link creates identity for the signed-in client only" do
    assert_settings_link_contract(PROVIDERS.fetch(:google))
  end

  test "Apple settings link creates identity for the signed-in client only" do
    assert_settings_link_contract(PROVIDERS.fetch(:apple))
  end

  test "Google settings link rejects a signed-in client without fresh social-link step-up" do
    user = create_social_client
    token = ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    assert_no_difference("ClientExternalIdentity.count") do
      post(
        settings_url_for(PROVIDERS.fetch(:google), ri: "jp"),
        headers: sign_user_headers(user, token),
      )
    end

    assert_response :see_other
    assert_includes response.location, "scope=social_link"
    assert_nil session[SocialAuth::SOCIAL_FLOW_ID_SESSION_KEY]
  end

  test "Apple settings link rejects a signed-in client without fresh social-link step-up" do
    user = create_social_client
    token = ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    assert_no_difference("ClientExternalIdentity.count") do
      post(
        settings_url_for(PROVIDERS.fetch(:apple), ri: "jp"),
        headers: sign_user_headers(user, token),
      )
    end

    assert_response :see_other
    assert_includes response.location, "scope=social_link"
    assert_nil session[SocialAuth::SOCIAL_FLOW_ID_SESSION_KEY]
  end

  test "Google settings link rejects replacing an existing provider with a different uid" do
    assert_settings_replacement_rejected(PROVIDERS.fetch(:google))
  end

  test "Apple settings link rejects replacing an existing provider with a different uid" do
    assert_settings_replacement_rejected(PROVIDERS.fetch(:apple))
  end

  test "Google settings unlink succeeds when Apple remains available" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google), user:, uid: "unlink_google")
    apple_identity = create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "backup_apple")

    delete_with_verified_session(user, PROVIDERS.fetch(:google))

    assert_redirected_to auth_app_settings_google_url(ri: "jp", host: @host)
    assert_not PROVIDERS.fetch(:google).fetch(:model).exists?(google_identity.id)
    assert PROVIDERS.fetch(:apple).fetch(:model).exists?(apple_identity.id)
  end

  test "Apple settings unlink succeeds when Google remains available" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google), user:, uid: "backup_google")
    apple_identity = create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "unlink_apple")

    delete_with_verified_session(user, PROVIDERS.fetch(:apple))

    assert_redirected_to auth_app_settings_apple_path(ri: "jp")
    assert PROVIDERS.fetch(:google).fetch(:model).exists?(google_identity.id)
    assert_not PROVIDERS.fetch(:apple).fetch(:model).exists?(apple_identity.id)
  end

  test "Apple settings link succeeds again after unlink while Google remains available" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google), user:, uid: "relink_backup_google")
    apple_identity = create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "relink_old_apple")

    delete_with_verified_session(user, PROVIDERS.fetch(:apple))

    assert_redirected_to auth_app_settings_apple_path(ri: "jp")
    assert PROVIDERS.fetch(:google).fetch(:model).exists?(google_identity.id)
    assert_not PROVIDERS.fetch(:apple).fetch(:model).exists?(apple_identity.id)

    new_uid = "relink_new_apple_#{SecureRandom.hex(4)}"
    grant_session = seed_app_social_link_grant_session(provider: "apple", user: user, ri: "jp")
    setup_mock_auth(PROVIDERS.fetch(:apple), uid: new_uid, token: "relinked_apple_token")

    # Settings link commits on Sign after the Sign-owned OAuth state and step-up checks.
    assert_no_difference("Client.count") do
      assert_difference("ClientExternalIdentity.count", 1) do
        perform_social_callback(
          PROVIDERS.fetch(:apple),
          params: { state: grant_session.state },
          headers: @callback_headers.merge(grant_session.user_headers),
        )
      end
    end

    assert_redirected_to auth_app_settings_path(ri: "jp")
    relinked_identity = ClientExternalIdentity.find_by!(provider: "apple", subject: new_uid)

    assert_equal user.id, relinked_identity.user_id
    assert_equal "active", relinked_identity.state
    assert PROVIDERS.fetch(:google).fetch(:model).exists?(google_identity.id)
  end

  test "Google settings unlink keeps the last active login method" do
    assert_last_social_unlink_rejected(PROVIDERS.fetch(:google))
  end

  test "Apple settings unlink keeps the last active login method" do
    assert_last_social_unlink_rejected(PROVIDERS.fetch(:apple))
  end

  test "Google settings unlink redirects to verification without social unlink step-up" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google), user:, uid: "step_up_google")
    create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "step_up_backup_apple")
    token = ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    delete(
      settings_url_for(PROVIDERS.fetch(:google), ri: "jp", host: @host),
      headers: sign_user_headers(user, token),
      params: { "cf-turnstile-response": "test" },
    )

    assert_response :unauthorized
    assert PROVIDERS.fetch(:google).fetch(:model).exists?(google_identity.id)
  end

  test "Apple settings unlink rejects a signed-in client without social unlink step-up" do
    user = create_social_client
    apple_identity = create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "step_up_apple")
    create_social_identity(PROVIDERS.fetch(:google), user:, uid: "step_up_backup_google")
    token = ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    delete(
      settings_url_for(PROVIDERS.fetch(:apple), ri: "jp", host: @host),
      headers: sign_user_headers(user, token),
      params: { "cf-turnstile-response": "test" },
    )

    assert_response :unauthorized
    assert PROVIDERS.fetch(:apple).fetch(:model).exists?(apple_identity.id)
  end

  test "Google settings link rejects settings step-up scope" do
    user = create_social_client
    token = ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_email")

    post(
      settings_url_for(PROVIDERS.fetch(:google), ri: "jp"),
      headers: as_user_headers(user, host: @host, session_public_id: token.public_id),
    )

    assert_response :see_other
    assert_match %r{\Ahttp://#{Regexp.escape(@host)}/verification\?}, response.location
    assert_includes response.location, "scope=social_link"
    assert_nil session[SocialAuth::SOCIAL_FLOW_ID_SESSION_KEY]
  end

  test "Google settings unlink rejects passcode as the only remaining method" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google), user:, uid: "passcode_google")
    create_login_secret_credential(user)

    delete_with_verified_session(user, PROVIDERS.fetch(:google))

    assert_response :unprocessable_content
    assert PROVIDERS.fetch(:google).fetch(:model).exists?(google_identity.id)
  end

  test "Google settings unlink rejects failed Turnstile before unlinking" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google), user:, uid: "turnstile_google")
    create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "turnstile_backup_apple")
    TurnstileVerifierStub.challenge_response = { "success" => false }

    delete_with_verified_session(user, PROVIDERS.fetch(:google))

    assert_response :see_other
    assert_redirected_to auth_app_settings_google_url(ri: "jp", host: @host)
    assert PROVIDERS.fetch(:google).fetch(:model).exists?(google_identity.id)
  end

  private

  def assert_social_signup_contract(config)
    uid = "#{config.fetch(:normalized)}_signup_#{SecureRandom.hex(4)}"
    state = seed_social_auth_session(provider: config.fetch(:provider), intent: "login", entry: "sign_up", ri: "jp")
    setup_mock_auth(config, uid:, token: "new_signup_token")

    assert_social_signup_callback_and_confirmation(config, state)
    cycle = ClientSignUpFlow.order(:id).last

    assert_social_signup_birthdate_and_completion(config, cycle)

    identity = config.fetch(:model).find_by!(provider: config.fetch(:provider), subject: uid)
    user = identity.user

    assert_response :redirect
    assert_equal "2000-02-03", user.reload.birthdate
    assert ClientToken.exists?(user_id: user.id)

    assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, user.status_id
    assert_equal "active", identity.state
    assert_equal config.fetch(:provider), identity.provider
    assert_not_nil identity.last_authenticated_at
    assert_nil ClientEmail.find_by(user: user)
  end

  def assert_social_signup_callback_and_confirmation(config, state)
    assert_no_difference("Client.count") do
      assert_no_difference("#{config.fetch(:model)}.count") do
        perform_social_callback(
          config,
          params: { state: state },
          headers: browser_headers.merge(@callback_headers),
        )
      end
    end

    assert_redirected_to public_send(:"auth_app_sign_up_guard_#{config.fetch(:normalized)}_url", ri: "jp")
    follow_redirect!

    assert_redirected_to public_send(:"auth_app_sign_up_check_#{config.fetch(:normalized)}_confirmation_url", ri: "jp")
    follow_redirect!

    assert_response :ok
    assert_equal "auth/app/sign/up/check/social/confirmations/show", inertia_component
    assert_predicate inertia_props.fetch("confirm_label"), :present?
  end

  def assert_social_signup_birthdate_and_completion(config, cycle)
    patch(
      public_send(:"auth_app_sign_up_check_#{config.fetch(:normalized)}_confirmation_url", ri: "jp"),
      params: { confirm_new_social_identity: "1", checkpoint_version: cycle.checkpoint_version },
      headers: browser_headers.merge(@callback_headers),
    )

    assert_redirected_to public_send(:"auth_app_sign_up_check_#{config.fetch(:normalized)}_birthdate_url", ri: "jp")
    follow_redirect!

    assert_no_difference("Client.count") do
      assert_no_difference("#{config.fetch(:model)}.count") do
        patch(
          public_send(:"auth_app_sign_up_check_#{config.fetch(:normalized)}_birthdate_url", ri: "jp"),
          params: {
            requirement: "birthdate",
            birthdate: "2000-02-03",
            checkpoint_version: cycle.reload.checkpoint_version,
          },
          headers: browser_headers.merge(@callback_headers),
        )
      end
    end

    assert_response :ok
    assert_includes response.body, "social-completion-form"

    assert_difference("Client.count", 1) do
      assert_difference("#{config.fetch(:model)}.count", 1) do
        submit_social_completion_if_present!
      end
    end
  end

  def assert_social_sign_in_contract(config)
    uid = "#{config.fetch(:normalized)}_signin_#{SecureRandom.hex(4)}"
    user = create_social_client
    identity = create_social_identity(config, user:, uid:)

    state = seed_social_auth_session(provider: config.fetch(:provider), intent: "login", ri: "jp")
    setup_mock_auth(config, uid:, token: "fresh_token")

    assert_no_difference("Client.count") do
      assert_no_difference("#{config.fetch(:model)}.count") do
        perform_social_callback(
          config,
          params: { state: state },
          headers: browser_headers.merge(@callback_headers),
        )
      end
    end

    # The completion form posts to the public base origin; Base root `/` is the
    # post-login landing (retired `/dashboard`).
    assert_redirected_to "https://#{ENV.fetch("PUBLIC_BASE_SERVICE_URL")}/"
    identity.reload

    assert_equal user.id, identity.user_id
    assert_not_nil identity.last_authenticated_at
  end

  def assert_settings_link_contract(config)
    uid = "#{config.fetch(:normalized)}_link_#{SecureRandom.hex(4)}"
    user = create_social_client

    grant_session = seed_app_social_link_grant_session(provider: config.fetch(:provider), user: user, ri: "jp")
    setup_mock_auth(config, uid:, token: "linked_token")

    # The sign callback creates the social identity directly for settings link.
    assert_no_difference("Client.count") do
      assert_difference("#{config.fetch(:model)}.count", 1) do
        perform_social_callback(
          config,
          params: { state: grant_session.state },
          headers: @callback_headers.merge(grant_session.user_headers),
        )
      end
    end

    assert_redirected_to auth_app_settings_path(ri: "jp")
    identity = config.fetch(:model).find_by!(provider: config.fetch(:provider), subject: uid)

    assert_equal user.id, identity.user_id
    assert_equal "active", identity.state
    assert_not_nil identity.last_authenticated_at
  end

  def assert_settings_replacement_rejected(config)
    user = create_social_client
    existing = create_social_identity(config, user:, uid: "existing_#{config.fetch(:normalized)}")

    headers = as_user_headers(user, host: @host)
    token = ClientToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    mark_token_step_up_satisfied_for_test(token, scope: SocialAuth::SOCIAL_LINK_SCOPE)

    assert_no_difference("#{config.fetch(:model)}.count") do
      post(settings_url_for(config, ri: "jp"), headers: headers)
    end

    assert_response :unprocessable_content
    existing.reload

    assert_equal "existing_#{config.fetch(:normalized)}", existing.uid
    assert_nil config.fetch(:model).find_by(
      provider: config.fetch(:provider),
      subject: "different_#{config.fetch(:normalized)}",
    )
  end

  def assert_last_social_unlink_rejected(config)
    user = create_social_client
    identity = create_social_identity(config, user:, uid: "last_#{config.fetch(:normalized)}")

    delete_with_verified_session(user, config)

    assert_response :unprocessable_content
    assert config.fetch(:model).exists?(identity.id)
  end

  def perform_social_callback(config, params:, headers:)
    if config.fetch(:provider) == "apple"
      get(auth_app_social_apple_callback_url(provider: "apple", ri: "jp"), params: params, headers: headers)
    else
      get(
        auth_app_social_google_callback_url(provider: config.fetch(:provider), ri: "jp"),
        params: params,
        headers: headers,
      )
    end
    submit_social_completion_if_present!
  end

  def setup_mock_auth(config, uid:, token:)
    normalized = config.fetch(:normalized)
    credentials = { token: token, expires_at: 1.week.from_now.to_i }
    credentials[:refresh_token] = "refresh_#{token}" if normalized == "apple"

    extra = {}
    extra[:id_info] = { nonce: session[:social_auth_nonce] } if normalized == "apple"

    OmniAuth.config.mock_auth[normalized.to_sym] = OmniAuth::AuthHash.new(
      provider: normalized,
      uid: uid,
      info: {},
      credentials: credentials,
      extra: extra,
    )
  end

  def create_social_client
    user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "soc_#{SecureRandom.hex(6)}",
      birthdate: "2000-02-03",
      last_step_up_at: 1.minute.ago,
    )
    ClientEmail.create!(
      user: user,
      address: "social-contract-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
    )
    ClientTotpCredential.create!(
      user: user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )
    user
  end

  def create_social_identity(config, user:, uid:)
    config.fetch(:model).create!(
      client: user,
      subject: uid,
      provider: config.fetch(:provider),
      issuer: ExternalAuthentication::ProviderRegistry.fetch(config.fetch(:provider)).issuer,
      audience: "#{config.fetch(:provider)}-test-client-id",
      verification_authority: "test",
      verified_at: Time.current,
      state: "active",
    )
  end

  def delete_with_verified_session(user, config)
    token = ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    satisfy_user_verification(token)
    mark_token_step_up_satisfied_for_test(token, scope: "social_unlink")

    delete(
      settings_url_for(config, ri: "jp", host: @host),
      headers: sign_user_headers(user, token),
      params: { "cf-turnstile-response": "test" },
    )
  end

  def settings_url_for(config, **params)
    public_send(:"auth_app_settings_#{config.fetch(:normalized)}_path", **params)
  end

  def sign_user_headers(user, token)
    as_user_headers(user, host: @host, session_public_id: token.public_id)
  end

  def token_bound_step_up_for_social_link(user)
    token = ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(token, scope: SocialAuth::SOCIAL_LINK_SCOPE)
    token
  end

  def create_login_secret_credential(user)
    ClientSecretCredentialKind.find_or_create_by!(id: ClientSecretCredentialKind::LOGIN)
    ClientSecretCredentialStatus.find_or_create_by!(id: ClientSecretCredentialStatus::ACTIVE)
    secret_credential = ClientSecretCredential.new(
      user: user,
      name: "passcode",
      password_digest: "digest",
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
      user_identity_secret_status_id: ClientSecretCredentialStatus::ACTIVE,
    )
    secret_credential.save!(validate: false)
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class SocialAuthAppFlowContractTest
  private
end

# DAMP local helper copy for former shared test support.
class SocialAuthAppFlowContractTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil, resource_type: nil,
                           dpop_jkt: nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || "unknown"
    resource_type ||=
      case resource
      when Client then "client"
      when Operator then "operator"
      when Visitor then "visitor"
      end
    AuthenticationToken.encode(
      resource,
      host: host_value,
      session_id: session_id,
      session_public_id: session_public_id,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: jwt_issuer_id_for_test_host(host_value, resource_type),
    )
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    base_hosts = {
      "APP" => [
        ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
        ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost"),
      ],
      "ORG" => [
        ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
        ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost"),
      ],
      "COM" => [
        ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
        ENV.fetch("PRIVATE_BASE_CORPORATE_URL", "www.com.localhost"),
      ],
    }
    base_surface = base_hosts.find { |_surface, hosts| hosts.include?(normalized) }&.first
    return "surface:BASE_#{base_surface}" if base_surface

    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "SIGN")
    surface =
      if service == "SIGN"
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
      address_digest: IdentifierBlindIndex.bidx_for_email(address),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
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
          address_digest: IdentifierBlindIndex.bidx_for_email(address),
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          otp_private_key: SecureRandom.base64(24),
          otp_counter: "",
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
      user_headers = as_user_headers(user, host: host)
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

# DAMP local social completion helpers for former shared test support.
class SocialAuthAppFlowContractTest
  private

  def seed_app_social_link_grant_session(provider:, user:, ri: "jp")
    host = @host || configured_host(:auth_service)
    host!(host) if respond_to?(:host!)

    user_headers = as_user_headers(user, host: host)
    session_public_id = user_headers.fetch("X-TEST-SESSION-PUBLIC-ID")
    token = ClientToken.find_by(public_id: session_public_id)
    session_ref = token&.try(:device_session)&.public_id.presence || session_public_id
    mark_token_step_up_satisfied_for_test(token, scope: SocialAuth::SOCIAL_LINK_SCOPE) if token

    issuance = IdentitySocialCeremonyGrantIssuer.issue!(
      surface: "app",
      actor_ref: user.public_id,
      session_ref: session_ref,
      operation: "link",
      provider: provider,
    )

    normalized_provider = SocialIdentifiable.normalize_provider(provider)
    continue_path = public_send(
      :"auth_app_settings_#{normalized_provider}_path",
      ri: ri,
      social_ceremony_grant: issuance.grant,
    )

    headers = social_callback_headers(host).merge(user_headers)
    post(continue_path, headers: headers)
    state = social_auth_state_from_response

    assert_predicate(
      state,
      :present?,
      "expected social auth state from response status=#{response.status} location=#{response.location.inspect} " \
      "flash=#{flash.to_hash.inspect} body=#{response.body.to_s.first(200).inspect}",
    )

    Struct.new(:state, :user_headers, :session_public_id, keyword_init: true).new(
      state: state,
      user_headers: user_headers,
      session_public_id: session_ref,
    )
  end

  def submit_social_completion_if_present!
    return unless response.media_type == "text/html"
    return unless response.body.include?("social-completion-form")

    # A browser only reaches the completion endpoint when CSP allows the form
    # target. See test/support/form_action_policy_helper.rb.
    assert_forms_submittable_under_policy

    form = response.parsed_body.at_css("form#social-completion-form")
    raise StandardError, "social completion form missing" unless form

    params = {}
    form.css("input").each do |input|
      name = input["name"]
      params[name] = input["value"] if name.present?
    end

    action_uri = URI.parse(form["action"])
    post(
      form["action"],
      params: params,
      headers: {
        "Host" => action_uri.host,
        "Origin" => "https://#{configured_host(:sign_service)}",
        "Sec-Fetch-Site" => "same-site",
      },
    )
    cookies.to_hash.each_key { |key| cookies.delete(key) }
  end
end

# DAMP local helper copy on the test class.
class SocialAuthAppFlowContractTest
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

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)
    return base unless user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"

    ensure_user_token_reference_records!
    token = session_public_id.present? ? ClientToken.find_by(public_id: session_public_id) : nil
    token ||= ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
    token ||= ClientToken.create!(
      user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    access_token = jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token if respond_to?(:cookies, true)
    base.merge("Authorization" => "Bearer #{access_token}")
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)
    return base unless staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"

    ensure_staff_token_reference_records!
    token = session_public_id.present? ? OperatorToken.find_by(public_id: session_public_id) : nil
    token ||= OperatorToken.where(staff_id: staff.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= OperatorToken.create!(
      staff_id: staff.id, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    access_token = jwt_access_token_for(
      staff, host: host, session_public_id: token.public_id,
             resource_type: "operator",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token if respond_to?(:cookies, true)
    base.merge("Authorization" => "Bearer #{access_token}")
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)
    return base unless visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"

    ensure_visitor_token_reference_records!
    token = session_public_id.present? ? VisitorToken.find_by(public_id: session_public_id) : nil
    token ||= VisitorToken.where(visitor_id: visitor.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= VisitorToken.create!(
      visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    access_token = jwt_access_token_for(
      visitor,
      host: host,
      session_public_id: token.public_id,
      resource_type: "visitor",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token if respond_to?(:cookies, true)
    base.merge("Authorization" => "Bearer #{access_token}")
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
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      {
        last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        last_step_up_aal: ("aal2" if token.respond_to?(:last_step_up_aal)),
        last_step_up_method: ("passkey" if token.respond_to?(:last_step_up_method)),
        last_step_up_session_public_id: (token.public_id if token.respond_to?(:last_step_up_session_public_id)),
        last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
        last_step_up_audience: (step_up_test_audience_for_token(token) if token.respond_to?(:last_step_up_audience)),
        updated_at: Time.current,
      }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(SIGN_APP SIGN_ORG SIGN_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
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
