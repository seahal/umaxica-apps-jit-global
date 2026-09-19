# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "minitest/mock"

class Auth::App::Settings::TotpsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients,
           :client_statuses,
           :client_token_statuses,
           :client_token_kinds,
           :client_secret_credential_kinds,
           :client_secret_credential_statuses,
           :client_totp_credential_statuses,
           :app_preference_chronicle_levels,
           :client_chronicle_events,
           :client_chronicle_levels

  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @user = clients(:one)
    # Clear existing TOTPs to avoid limit error
    @user.client_totp_credentials.destroy_all
    @user.client_secret_credentials.destroy_all
    create_client_recovery_passcode!(@user, name: "recovery 1")
    create_client_recovery_passcode!(@user, name: "recovery 2")
    ClientEmail.create!(
      user: @user,
      address: "totp-config-test@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    @token = ClientToken.create!(user_id: @user.id)
    @token.rotate_refresh_token!
    access_token = AuthenticationToken.encode(
      @user,
      host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      session_public_id: @token.public_id,
      jwt_issuer_id: jwt_issuer_id_for_test_host(ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), "client"),
    )
    @headers = {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze
    @token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "settings_totp")
    cookies["csrf_token"] = "test_csrf_token"
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    satisfy_user_verification(@token)
    @headers.freeze

    @totp = ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      last_otp_at: Time.zone.at(0),
      title: "Main TOTP",
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )

    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    IdentityTotpCeremonyCandidate.find_each(&:destroy!)
  end

  def with_prosopite_paused
    Prosopite.pause { yield }
  end

  def headers_for_client_token(token, scope:, step_up_at: Time.current)
    Actor.clear if defined?(Actor)
    mark_settings_step_up_satisfied!(token, scope: scope, at: step_up_at)
    access_token = AuthenticationToken.encode(
      token.user,
      host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      session_public_id: token.public_id,
      resource_type: "client",
      jwt_issuer_id: jwt_issuer_id_for_test_host(ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), "client"),
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    @headers.merge(
      "Authorization" => "Bearer #{access_token}",
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )
  end

  def mark_settings_step_up_satisfied!(token, scope:, at:)
    token.update_columns(
      last_step_up_at: at,
      last_step_up_scope: scope,
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
      updated_at: Time.current,
    )
  end

  test "should get index" do
    with_prosopite_paused do
      get auth_app_settings_totps_url(ri: "jp"), headers: @headers
    end

    assert_response :ok
    assert_equal "auth/app/settings/totps/index", inertia_component
    assert_equal(
      [@totp.public_id],
      inertia_props.fetch("totps").map { |row| row.fetch("public_id") },
    )
  end

  test "index stays accessible when no totp is registered" do
    user = Client.create!(status_id: ClientStatus::NOTHING)
    token = ClientToken.create!(user_id: user.id)
    satisfy_user_verification(token)
    access_token = AuthenticationToken.encode(
      user,
      host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      session_public_id: token.public_id,
      jwt_issuer_id: jwt_issuer_id_for_test_host(ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), "client"),
    )
    headers = {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
    cookies["csrf_token"] = "test_csrf_token"
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    with_prosopite_paused do
      get auth_app_settings_totps_url(ri: "jp"), headers: headers
    end

    assert_response :ok
    assert_empty inertia_props.fetch("totps")
    assert_equal I18n.t("messages.no_totp_found"), inertia_props.fetch("empty_message")
  end

  test "index requires step up when multi factor status is active even without totp" do
    user = Client.create!(status_id: ClientStatus::NOTHING)
    ClientEmail.create!(
      user: user,
      address: "totp-active-with-email@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    token = ClientToken.create!(user_id: user.id)
    token.update!(created_at: 1.hour.ago, last_step_up_at: nil, last_step_up_scope: nil)
    access_token = AuthenticationToken.encode(
      user,
      host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      session_public_id: token.public_id,
      jwt_issuer_id: jwt_issuer_id_for_test_host(ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), "client"),
    )
    headers = {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
    cookies["csrf_token"] = "test_csrf_token"
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    with_prosopite_paused do
      get auth_app_settings_totps_url(ri: "jp"), headers: headers
    end

    assert_response :ok
    assert_equal ClientMfaStatus::ACTIVE, user.reload.mfa_status_id
  end

  test "should show up link on index page" do
    with_prosopite_paused do
      get auth_app_settings_totps_url(ri: "jp"), headers: @headers
    end

    assert_response :ok
    assert_equal(
      new_auth_app_settings_totp_path(ri: "jp"),
      inertia_props.fetch("new_link").fetch("href"),
    )
  end

  test "should get new" do
    with_prosopite_paused do
      get new_auth_app_settings_totp_url(ri: "jp"), headers: @headers
    end

    assert_response :success
    assert_equal "auth/app/settings/totps/new", inertia_component
    assert_equal(
      auth_app_settings_totps_path(ri: "jp"),
      inertia_props.fetch("back_link").fetch("href"),
    )

    form = inertia_props.fetch("form")

    assert_equal auth_app_settings_totps_path(ri: "jp"), form.fetch("action")
    assert_equal "user_totp_credential", form.fetch("scope")
    assert_equal(
      I18n.t("views.sign.app.settings.totps.new.first_token_label"),
      form.fetch("first_token_label"),
    )
    assert_equal(
      I18n.t("views.sign.app.settings.totps.new.first_token_placeholder"),
      form.fetch("first_token_placeholder"),
    )
    assert_equal I18n.t("views.sign.app.settings.totps.new.submit"), form.fetch("submit_label")
    assert_includes response.body, "認証アプリ"
    assert_equal(
      I18n.t("views.sign.app.settings.totps.new.first_token_delivery_help"),
      form.fetch("first_token_delivery_help"),
    )
    assert_not_includes response.body, "届きます"
    assert_not_includes response.body, "送信され"
    assert_predicate inertia_props.fetch("turnstile").fetch("site_key"), :present?
    assert_match %r{\Adata:image/png;base64,}, inertia_props.fetch("qr_code_image")
  end

  test "new refuses to start another authenticator once the limit is reached" do
    @user.client_totp_credentials.destroy_all
    Auth::App::Settings::TotpsController::MAX_TOTPS.times do |index|
      ClientTotpCredential.create!(
        user: @user,
        private_key: ROTP::Base32.random_base32,
        user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
        title: "totp-#{index}",
      )
    end

    with_prosopite_paused do
      get new_auth_app_settings_totp_url(ri: "jp"), headers: @headers
    end

    assert_response :success
    assert_equal I18n.t(
      "session_limit.totp_limit_reached",
      count: Auth::App::Settings::TotpsController::MAX_TOTPS,
    ), response.body
  end

  test "new allows bootstrap with zero unused usable recovery passcodes" do
    @user.client_totp_credentials.destroy_all
    @user.client_secret_credentials.destroy_all

    get new_auth_app_settings_totp_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_not_includes response.body, base_app_identity_secrets_url(
      ri: "jp",
      host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
    )
  end

  test "create tops recovery passcodes up after bootstrap with one existing recovery passcode" do
    @user.client_totp_credentials.destroy_all
    @user.client_secret_credentials.destroy_all
    create_client_recovery_passcode!(@user, name: "only recovery")

    with_mocked_totp do |secret_credential|
      get new_auth_app_settings_totp_url(ri: "jp"), headers: @headers
      # TOTP codes are only valid for a 30-second window, so generation and the
      # verifying request are pinned to the same instant -- otherwise a slow run can
      # straddle a window boundary and turn a valid code invalid before it arrives.
      freeze_time do
        token = ROTP::TOTP.new(secret_credential).now

        assert_difference("ClientTotpCredential.count", 1) do
          assert_difference(-> { @user.reload.client_secret_credentials.count }, 9) do
            post auth_app_settings_totps_url(ri: "jp"),
                 params: {
                   user_totp_credential: { first_token: token },
                 },
                 headers: @headers
          end
        end
      end
    end

    assert_response :see_other
    assert_includes response.location, "/identity/secrets"
  end

  test "used and revoked recovery passcodes are not counted" do
    @user.client_secret_credentials.destroy_all
    create_client_recovery_passcode!(@user, name: "used", last_used_at: Time.current)
    create_client_recovery_passcode!(
      @user,
      name: "revoked",
      status_id: ClientSecretCredentialStatus::REVOKED,
    )

    get new_auth_app_settings_totp_url(ri: "jp"), headers: @headers

    assert_response :forbidden
  end

  test "should get edit with public_id" do
    with_prosopite_paused do
      get edit_auth_app_settings_totp_url(@totp.public_id, ri: "jp"), headers: @headers
    end

    assert_response :ok
    assert_equal "auth/app/settings/totps/edit", inertia_component
    assert_equal(
      auth_app_settings_totp_path(@totp.public_id, ri: "jp"),
      inertia_props.fetch("form").fetch("action"),
    )
    assert_equal @totp.public_id, request.path_parameters[:id]
    assert_nil request.path_parameters[:public_id]
  end

  test "should update title with public_id" do
    with_prosopite_paused do
      patch auth_app_settings_totp_url(@totp.public_id, ri: "jp"),
            params: { user_totp_credential: { title: "Updated TOTP" } },
            headers: @headers
    end

    assert_redirected_to auth_app_settings_totp_path(@totp.public_id, ri: "jp")
    assert_equal "Updated TOTP", @totp.reload.title
  end

  test "should destroy with public_id" do
    headers = headers_for_client_token(@token, scope: "settings_totp")

    before_count = ClientTotpCredential.count
    with_prosopite_paused do
      delete auth_app_settings_totp_url(@totp.public_id, ri: "jp"), headers: headers
    end

    assert_redirected_to auth_app_settings_totps_path(ri: "jp")
    assert_equal before_count - 1, ClientTotpCredential.count
  end

  test "destroy requires fresh settings totp step up" do
    @token.update!(last_step_up_at: 20.minutes.ago, last_step_up_scope: "settings_totp")
    headers = headers_for_client_token(@token, scope: "settings_totp", step_up_at: 20.minutes.ago)

    assert_no_difference("ClientTotpCredential.count") do
      with_prosopite_paused do
        delete auth_app_settings_totp_url(@totp.public_id, ri: "jp"), headers: headers
      end
    end

    assert_response :unauthorized
    assert_includes response.body, "Step-up authentication required"
  end

  test "should return 404 for other user's totp" do
    other_user = clients(:two)
    other_totp = ClientTotpCredential.create!(
      user: other_user,
      private_key: ROTP::Base32.random_base32,
      last_otp_at: Time.zone.at(0),
      title: "Other TOTP",
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )

    with_prosopite_paused do
      get edit_auth_app_settings_totp_url(other_totp.public_id, ri: "jp"), headers: @headers
    end

    assert_response :not_found
  end

  test "should create totp with valid token" do
    # Clear TOTP created in setup to allow creation of a new one (limit is 2)
    @user.client_totp_credentials.destroy_all
    @user.client_secret_credentials.destroy_all

    with_mocked_totp do |secret_credential|
      with_prosopite_paused do
        get new_auth_app_settings_totp_url(ri: "jp"), headers: @headers
      end

      assert_response :success
      assert_predicate inertia_props.fetch("turnstile").fetch("site_key"), :present?
      step_up_before = Time.current

      # TOTP codes are only valid for a 30-second window, so the generation and the
      # verifying request are pinned to the same instant -- otherwise the assertion
      # under a slow run (e.g. line-coverage instrumentation) can straddle a window
      # boundary and turn a valid code invalid before the request reaches it.
      travel_to(step_up_before) do
        token = ROTP::TOTP.new(secret_credential).now

        assert_difference("ClientTotpCredential.count", 1) do
          assert_difference(-> { @user.reload.client_secret_credentials.count }, 10) do
            with_prosopite_paused do
              post auth_app_settings_totps_url(ri: "jp"),
                   params: { user_totp_credential: { first_token: token } },
                   headers: @headers
            end
          end
        end
      end

      assert_response :see_other
      assert_includes response.location, "/identity/secrets"
      assert_operator @token.reload.last_step_up_at, :<, step_up_before
      assert_equal "settings_totp", @token.last_step_up_scope
    end
  end

  test "create tops up only the shortfall when some recovery passcodes already exist" do
    @user.client_totp_credentials.destroy_all
    @user.client_secret_credentials.destroy_all
    5.times do |index|
      create_client_recovery_passcode!(@user, name: "existing #{index + 1}")
    end

    with_mocked_totp do |secret_credential|
      with_prosopite_paused do
        get new_auth_app_settings_totp_url(ri: "jp"), headers: @headers
      end

      freeze_time do
        token = ROTP::TOTP.new(secret_credential).now

        assert_difference("ClientTotpCredential.count", 1) do
          assert_difference(-> { @user.reload.client_secret_credentials.count }, 5) do
            with_prosopite_paused do
              post auth_app_settings_totps_url(ri: "jp"),
                   params: { user_totp_credential: { first_token: token } },
                   headers: @headers
            end
          end
        end
      end

      assert_response :see_other
      assert_includes response.location, "/identity/secrets"
    end
  end

  test "should assign attributes to created totp" do
    @user.client_totp_credentials.destroy_all

    with_mocked_totp do |secret_credential|
      with_prosopite_paused do
        get new_auth_app_settings_totp_url(ri: "jp"), headers: @headers
      end

      assert_response :success
      assert_predicate inertia_props.fetch("turnstile").fetch("site_key"), :present?
      freeze_time do
        token = ROTP::TOTP.new(secret_credential).now

        with_prosopite_paused do
          post auth_app_settings_totps_url(ri: "jp"),
               params: {
                 user_totp_credential: { first_token: token, title: "New TOTP" },
               },
               headers: @headers
        end
      end

      created_totp = ClientTotpCredential.order(created_at: :desc).first

      assert_equal "New TOTP", created_totp.title
      assert_not_nil created_totp.last_otp_at
    end
  end

  test "should create totp with pasted token containing spaces" do
    @user.client_totp_credentials.destroy_all

    with_mocked_totp do |secret_credential|
      with_prosopite_paused do
        get new_auth_app_settings_totp_url(ri: "jp"), headers: @headers
      end

      freeze_time do
        raw_token = ROTP::TOTP.new(secret_credential).now
        pasted_token = "#{raw_token.first(3)} #{raw_token.last(3)}"

        assert_difference("ClientTotpCredential.count", 1) do
          with_prosopite_paused do
            post auth_app_settings_totps_url(ri: "jp"),
                 params: {
                   user_totp_credential: { first_token: pasted_token, title: "Pasted TOTP" },
                 },
                 headers: @headers
          end
        end
      end
    end

    assert_response :see_other
    assert_includes response.location, "/identity/secrets"
  end

  test "should not create totp with invalid token" do
    with_prosopite_paused do
      get new_auth_app_settings_totp_url(ri: "jp"), headers: @headers
    end

    assert_response :success
    assert_predicate inertia_props.fetch("turnstile").fetch("site_key"), :present?

    assert_no_difference("ClientTotpCredential.count") do
      with_prosopite_paused do
        post auth_app_settings_totps_url(ri: "jp"),
             params: { user_totp_credential: { first_token: "000000" } },
             headers: @headers
      end
    end

    assert_response :unprocessable_content
  end

  test "should not create totp with empty token" do
    with_prosopite_paused do
      get new_auth_app_settings_totp_url(ri: "jp"), headers: @headers
    end

    assert_response :success

    assert_no_difference("ClientTotpCredential.count") do
      with_prosopite_paused do
        post auth_app_settings_totps_url(ri: "jp"),
             params: { user_totp_credential: { first_token: "", title: "" } },
             headers: @headers
      end
    end

    assert_response :unprocessable_content
    assert_equal "auth/app/settings/totps/new", inertia_component
    assert_includes inertia_props.fetch("error_messages").join("\n"),
                    I18n.t("sign.app.settings.totps.invalid_code")
  end

  test "should not create totp when turnstile stealth fails" do
    with_mocked_totp do |secret_credential|
      with_prosopite_paused do
        get new_auth_app_settings_totp_url(ri: "jp"), headers: @headers
      end

      assert_response :success
      assert_predicate inertia_props.fetch("turnstile").fetch("site_key"), :present?

      TurnstileVerifierStub.challenge_response = { "success" => false }
      freeze_time do
        token = ROTP::TOTP.new(secret_credential).now

        assert_no_difference("ClientTotpCredential.count") do
          with_prosopite_paused do
            post auth_app_settings_totps_url(ri: "jp"),
                 params: {
                   user_totp_credential: { first_token: token, title: "Blocked TOTP" },
                 },
                 headers: @headers
          end
        end
      end
    end

    assert_response :unprocessable_content
    assert_equal "auth/app/settings/totps/new", inertia_component
    assert_includes inertia_props.fetch("error_messages").join("\n"), I18n.t("turnstile_error")
  end

  test "initial setup user can access totp pages without step-up" do
    user = create_verified_user_with_email(email_address: "initial_totp_access@example.com")
    token = ClientToken.create!(user_id: user.id)
    token.rotate_refresh_token!
    token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "settings_totp")
    satisfy_user_verification(token)
    access_token = AuthenticationToken.encode(
      user,
      host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      session_public_id: token.public_id,
      jwt_issuer_id: jwt_issuer_id_for_test_host(ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), "client"),
    )
    headers = {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
    cookies["csrf_token"] = "test_csrf_token"
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    satisfy_user_verification(token)

    with_prosopite_paused do
      get auth_app_settings_totps_url(ri: "jp"), headers: headers
    end

    assert_response :ok
  end

  test "initial setup user can create first totp without step-up" do
    user = create_verified_user_with_email(email_address: "initial_totp_create@example.com")
    create_client_recovery_passcode!(user, name: "initial 1")
    create_client_recovery_passcode!(user, name: "initial 2")
    token = ClientToken.create!(user_id: user.id)
    token.rotate_refresh_token!
    token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "settings_totp")
    satisfy_user_verification(token)
    access_token = AuthenticationToken.encode(
      user,
      host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      session_public_id: token.public_id,
      jwt_issuer_id: jwt_issuer_id_for_test_host(ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), "client"),
    )
    headers = {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
    cookies["csrf_token"] = "test_csrf_token"
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    satisfy_user_verification(token)

    with_mocked_totp do |secret_credential|
      with_prosopite_paused do
        get new_auth_app_settings_totp_url(
          ri: "jp",
        ), headers: headers
      end

      assert_response :success
      freeze_time do
        first_code = ROTP::TOTP.new(secret_credential).now

        assert_difference("ClientTotpCredential.count", 1) do
          with_prosopite_paused do
            post auth_app_settings_totps_url(ri: "jp"),
                 params: { user_totp_credential: { first_token: first_code } },
                 headers: headers
          end
        end
      end
    end

    assert_response :see_other
    assert_includes response.location, "/identity/secrets"
  end

  private

  private

  def with_mocked_totp
    known_secret_credential = "JBSWY3DPEHPK3PXP"
    ROTP::Base32.stub(:random_base32, known_secret_credential) do
      yield known_secret_credential
    end
  end

  def create_client_recovery_passcode!(
    user,
    name:,
    status_id: ClientSecretCredentialStatus::ACTIVE,
    last_used_at: nil
  )
    credential = user.client_secret_credentials.new(
      name: name,
      user_secret_kind_id: ClientSecretCredentialKind::RECOVERY,
      user_identity_secret_status_id: status_id,
      last_used_at: last_used_at,
    )
    credential.password = ClientSecretCredential.generate_raw_secret_credential
    credential.save!(validate: false)
    credential
  end
end

# DAMP local helper copy for former shared test support.
class Auth::App::Settings::TotpsControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

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

# DAMP local helper copy on the test class.
class Auth::App::Settings::TotpsControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

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
    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
      }",
      )
    else
      base
    end
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
    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }",
      )
    else
      base
    end
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
    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor")
      }",
      )
    else
      base
    end
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
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

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
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

    attrs = {
      last_step_up_at: at,
      last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
      last_step_up_aal: ("aal2" if token.has_attribute?(:last_step_up_aal)),
      last_step_up_method: ("passkey" if token.has_attribute?(:last_step_up_method)),
      last_step_up_session_public_id: (token.public_id if token.has_attribute?(:last_step_up_session_public_id)),
      last_step_up_purpose: ("step_up" if token.has_attribute?(:last_step_up_purpose)),
      last_step_up_audience: (step_up_test_audience_for_token(token) if token.has_attribute?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
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

  def csrf_token_value
    "test-csrf-token"
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
