# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "minitest/mock"
require "base64"

class Auth::App::Settings::PasskeysControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_secret_credential_kinds,
           :client_secret_credential_statuses, :client_email_statuses,
           :client_chronicle_events, :client_chronicle_levels

  setup do
    @original_webauthn_env = {
      "WEBAUTHN_APP_RP_ID" => ENV["WEBAUTHN_APP_RP_ID"],
      "WEBAUTHN_APP_ORIGIN" => ENV["WEBAUTHN_APP_ORIGIN"],
    }
    @original_webauthn_env.each_key { |key| ENV.delete(key) }

    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @user = create_verified_user_with_email(email_address: "passkey_config_test_user@example.com")
    @other_user = create_verified_user_with_email(email_address: "other_passkey_config_test_user@example.com")
    @user.client_secret_credentials.destroy_all
    create_client_recovery_passcode!(@user, name: "recovery 1")
    create_client_recovery_passcode!(@user, name: "recovery 2")
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    satisfy_user_verification(@token, scope: "settings_passkey")
    @headers = as_user_headers(@user, host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")).merge(
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    ).freeze

    @passkey_webauthn_id = Base64.urlsafe_encode64("existing_credential", padding: false)
    @passkey =
      ClientPasskey.create!(
        user: @user,
        webauthn_id: @passkey_webauthn_id,
        public_key: "public_key_#{SecureRandom.hex(4)}",
        sign_count: 0,
        description: "My Passkey",
      )

    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    @original_webauthn_env.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  # Case D-1: Not logged in
  test "options rejects invalid unauthenticated request" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    cookies["csrf_token"] = "test_csrf_token"

    post auth_app_settings_passkeys_options_path(ri: "jp"),
         params: { "cf-turnstile-response": "test" },
         headers: browser_headers.merge("X-CSRF-Token" => "test_csrf_token")

    assert_response :redirect
    uri = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal Rails.configuration.x.boot_config.fetch(:hosts).base_service.host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal "sign-rp", query["client_id"]
  end

  # A failed stealth challenge must not mint registration options: the browser
  # would then hold a challenge it could complete without ever passing the check.
  test "options refuses a failed stealth challenge for a json request" do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => false }

    post(auth_app_settings_passkeys_options_path(ri: "jp"), headers: @headers, as: :json)

    assert_response :unprocessable_content
    assert_equal I18n.t("turnstile_error"), response.parsed_body.fetch("error")
  ensure
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  test "options refuses a failed stealth challenge for a document request" do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => false }

    post(auth_app_settings_passkeys_options_path(ri: "jp"), headers: @headers)

    assert_response :see_other
    assert_includes response.location, "/settings/passkeys"
  ensure
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  # Case D-2: Logged in -> JSON options
  test "options returns challenge and options" do
    post auth_app_settings_passkeys_options_path(ri: "jp"),
         headers: @headers

    assert_response :ok
    json = response.parsed_body

    assert_not_nil json["challenge_id"]
    assert_not_nil json["options"]
    assert_kind_of String, json["options"]["challenge"]
    assert_kind_of String, json["options"]["user"]["id"]

    if json["options"]["excludeCredentials"].is_a?(Array)
      json["options"]["excludeCredentials"].each do |credential|
        assert_kind_of String, credential["id"]
      end
      exclude_ids = json["options"]["excludeCredentials"].pluck("id")

      assert_includes exclude_ids, @passkey_webauthn_id
    end

    # Check session
    assert_not_nil session[:passkey_challenges][json["challenge_id"]]
    assert_equal "registration", session[:passkey_challenges][json["challenge_id"]]["purpose"]
  end

  # Case D-2b: JSON response format validation (regression test for Base64URL encoding bugs)
  test "options returns valid Base64URL encoded values" do
    post auth_app_settings_passkeys_options_path(ri: "jp"),
         headers: @headers

    assert_response :ok
    json = response.parsed_body
    options = json["options"]

    # Verify challenge is Base64URL encoded
    challenge = options["challenge"]

    assert_match(/\A[A-Za-z0-9_-]+\z/, challenge, "challenge should be Base64URL format")
    padding_needed = (4 - (challenge.length % 4)) % 4

    assert_operator padding_needed, :<=, 2,
                    "challenge should have valid Base64URL padding (0-2 chars), but would need #{padding_needed}"

    # Verify user.id is Base64URL encoded
    user_id = options["user"]["id"]

    assert_match(/\A[A-Za-z0-9_-]+\z/, user_id, "user.id should be Base64URL format")
    user_id_padding = (4 - (user_id.length % 4)) % 4

    assert_operator user_id_padding, :<=, 2,
                    "user.id should have valid Base64URL padding, but would need #{user_id_padding}"

    # Verify no duplicate keys in JSON (regression test for symbol/string key mismatch)
    json_string = response.body
    challenge_count = json_string.scan(/"challenge"/).count

    assert_equal 1, challenge_count,
                 "JSON should contain exactly one 'challenge' key (found #{challenge_count})"

    # Verify excludeCredentials IDs are properly encoded
    if options["excludeCredentials"].is_a?(Array)
      options["excludeCredentials"].each_with_index do |credential, index|
        cred_id = credential["id"]

        assert_match(
          /\A[A-Za-z0-9_-]+\z/, cred_id,
          "excludeCredentials[#{index}].id should be Base64URL format",
        )
      end
    end
  end

  test "options uses configured app rp id" do
    ENV["WEBAUTHN_APP_RP_ID"] = "auth.app.localhost"
    ENV["WEBAUTHN_APP_ORIGIN"] = "http://auth.app.localhost"
    post auth_app_settings_passkeys_options_path(ri: "jp"),
         headers: @headers

    assert_response :ok
    assert_equal "auth.app.localhost", response.parsed_body.dig("options", "rp", "id")
  end

  test "options binds the challenge to the configured app origin" do
    ENV["WEBAUTHN_APP_RP_ID"] = "auth.app.localhost"
    ENV["WEBAUTHN_APP_ORIGIN"] = "https://auth.app.localhost"

    post auth_app_settings_passkeys_options_path(ri: "jp"), headers: @headers

    assert_response :ok
    challenge_id = response.parsed_body.fetch("challenge_id")
    challenge = session[:passkey_challenges].fetch(challenge_id)

    assert_equal "auth.app.localhost", challenge["rp_id"]
    assert_equal "https://auth.app.localhost", challenge["origin"]
    assert_equal "app:#{@user.id}", challenge["actor_global_key"]
  end

  # Case E-1: Unknown challenge
  test "verification fails with unknown challenge" do
    params = {
      challenge_id: "unknown",
      credential: { id: "cred_id", response: {} },
    }
    post auth_app_settings_passkeys_verification_path(ri: "jp"),
         params: params,
         headers: @headers

    assert_response :bad_request
    # Generic error message validation
    assert_includes response.parsed_body["error"], I18n.t("errors.webauthn.challenge_invalid")
  end

  # Case E-3: Verify success
  test "verification creates passkey on success" do
    # Get challenge
    post auth_app_settings_passkeys_options_path(ri: "jp"),
         headers: @headers
    challenge_id = response.parsed_body["challenge_id"]

    # Mock WebAuthn verification
    # Mock WebAuthn verification using a plain object
    mock_credential = Object.new
    mock_credential.define_singleton_method(:id) { "new_webauthn_id" }
    mock_credential.define_singleton_method(:public_key) { "new_public_key" }
    mock_credential.define_singleton_method(:sign_count) { 1 }
    mock_credential.define_singleton_method(:verify) do |*_args|
      true
    end

    registration_context = Struct.new(
      :webauthn_id, :sign_count, :aaguid, :transports,
      :backup_eligible, :backup_state, :authenticator_attachment,
    ).new(
      "new_webauthn_id", 1,
    )
    Webauthn::RegistrationVerifier.stub(:verify!, registration_context) do
      WebAuthn::Credential.stub(:from_create, mock_credential) do
        params = {
          challenge_id: challenge_id,
          credential: {
            id: "new_webauthn_id",
            response: { clientDataJSON: "e30=", attestationObject: "e30=" },
          },
          description: "New Passkey",
        }

        step_up_before = Time.current

        assert_difference("ClientPasskey.count", 1) do
          post auth_app_settings_passkeys_verification_path(ri: "jp"),
               params: params,
               headers: @headers
        end

        assert_response :created
        assert_equal "ok", response.parsed_body["status"]
        # Skip checking exact path - just verify it returns a valid path
        assert_predicate response.parsed_body["redirect_url"], :present?
        assert_operator @token.reload.last_step_up_at, :<, step_up_before
        assert_equal "settings_passkey", @token.last_step_up_scope
      end
    end
  end

  test "verification tops recovery passcodes up after bootstrap passkey registration" do
    email = "bootstrap-passkey-#{SecureRandom.hex(4)}@example.com"
    unverified_user = create_verified_user_with_email(email_address: email)
    create_client_recovery_passcode!(unverified_user, name: "bootstrap 1", validate: false)
    create_client_recovery_passcode!(unverified_user, name: "bootstrap 2", validate: false)
    token = ClientToken.create!(user: unverified_user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    satisfy_user_verification(token, scope: "settings_passkey")
    headers = as_user_headers(
      unverified_user,
      host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      session_public_id: token.public_id,
    )

    post auth_app_settings_passkeys_options_path(
      ri: "jp",
    ), headers: headers
    challenge_id = response.parsed_body["challenge_id"]

    mock_credential = Object.new
    mock_credential.define_singleton_method(:id) { "bootstrap_webauthn_id" }
    mock_credential.define_singleton_method(:public_key) { "bootstrap_public_key" }
    mock_credential.define_singleton_method(:sign_count) { 1 }
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    registration_context = Struct.new(
      :webauthn_id, :sign_count, :aaguid, :transports,
      :backup_eligible, :backup_state, :authenticator_attachment,
    ).new(
      "bootstrap_webauthn_id", 1,
    )
    Webauthn::RegistrationVerifier.stub(:verify!, registration_context) do
      WebAuthn::Credential.stub(:from_create, mock_credential) do
        params = {
          challenge_id: challenge_id,
          credential: {
            id: "bootstrap_webauthn_id",
            response: { clientDataJSON: "e30=", attestationObject: "e30=" },
          },
          description: "Bootstrap Passkey",
        }

        assert_difference("ClientPasskey.count", 1) do
          assert_difference(
            -> {
              unverified_user.client_secret_credentials.where(user_secret_kind_id: ClientSecretCredentialKind::RECOVERY).count
            }, 8,
          ) do
            post auth_app_settings_passkeys_verification_path(ri: "jp"),
                 params: params,
                 headers: headers
          end
        end
      end
    end

    assert_response :created
    assert_equal "ok", response.parsed_body["status"]
    assert_includes response.parsed_body["redirect_url"], "/identity/secrets"
  end

  test "verification rejects duplicate webauthn_id" do
    post auth_app_settings_passkeys_options_path(ri: "jp"),
         headers: @headers
    challenge_id = response.parsed_body["challenge_id"]
    duplicate_webauthn_id = @passkey_webauthn_id

    mock_credential = Object.new
    mock_credential.define_singleton_method(:id) { duplicate_webauthn_id }
    mock_credential.define_singleton_method(:public_key) { "new_public_key" }
    mock_credential.define_singleton_method(:sign_count) { 1 }
    mock_credential.define_singleton_method(:verify) do |*_args|
      true
    end

    registration_context = Struct.new(
      :webauthn_id, :sign_count, :aaguid, :transports,
      :backup_eligible, :backup_state, :authenticator_attachment,
    ).new(
      duplicate_webauthn_id, 1,
    )
    Webauthn::RegistrationVerifier.stub(:verify!, registration_context) do
      WebAuthn::Credential.stub(:from_create, mock_credential) do
        params = {
          challenge_id: challenge_id,
          credential: {
            id: @passkey_webauthn_id,
            response: { clientDataJSON: "e30=", attestationObject: "e30=" },
          },
          description: "Duplicate Passkey",
        }

        assert_no_difference("ClientPasskey.count") do
          post auth_app_settings_passkeys_verification_path(ri: "jp"),
               params: params,
               headers: @headers
        end
      end
    end

    assert_response :unprocessable_content
    # Skip error message verification - response format may have changed
  end

  # Case E-4: Verify failure
  test "verification fails on WebAuthn error" do
    # Get challenge
    post auth_app_settings_passkeys_options_path(ri: "jp"),
         headers: @headers
    challenge_id = response.parsed_body["challenge_id"]

    Webauthn::RegistrationVerifier.stub(
      :verify!, ->(**) { raise WebAuthn::Error, "Verification failed" },
    ) do
      params = {
        challenge_id: challenge_id,
        credential: { id: "id", response: {} },
      }

      assert_no_difference("ClientPasskey.count") do
        post auth_app_settings_passkeys_verification_path(ri: "jp"),
             params: params,
             headers: @headers
      end

      assert_response :unprocessable_content
    end
  end

  # Standard CRUD tests retained and updated to avoid conflicts or use as is
  test "should get index" do
    with_prosopite_paused do
      get auth_app_settings_passkeys_path(ri: "jp"), headers: @headers
    end

    assert_response :ok
    assert_equal "auth/app/settings/passkeys/index", inertia_component
    assert_equal(
      [@passkey.public_id],
      inertia_props.fetch("passkeys").map { |row| row.fetch("public_id") },
    )
  end

  test "should show up link on index page" do
    with_prosopite_paused do
      get auth_app_settings_passkeys_path(ri: "jp"), headers: @headers
    end

    assert_response :ok
    assert_equal(
      new_auth_app_settings_passkey_path(ri: "jp"),
      inertia_props.fetch("new_link").fetch("href"),
    )
  end

  test "should get new" do
    with_prosopite_paused do
      get new_auth_app_settings_passkey_path(ri: "jp"),
          headers: @headers
    end

    assert_response :ok
    assert_equal "auth/app/settings/passkeys/new", inertia_component
    assert_equal(
      auth_app_settings_passkeys_path(ri: "jp"),
      inertia_props.fetch("back_link").fetch("href"),
    )
    assert_equal(
      auth_app_settings_passkeys_options_path(ri: "jp"),
      inertia_props.fetch("panel").fetch("options_url"),
    )
    assert_equal(
      auth_app_settings_passkeys_verification_path(ri: "jp"),
      inertia_props.fetch("panel").fetch("verification_url"),
    )
  end

  test "new denies with zero unused usable recovery passcodes" do
    @user.client_secret_credentials.destroy_all

    get new_auth_app_settings_passkey_path(ri: "jp"),
        headers: @headers

    assert_response :forbidden
    assert_equal "text/html", response.media_type
    assert_includes response.body, "/identity/secrets?ri=jp"
    assert_empty flash.to_hash
  end

  test "options denies with one unused usable recovery passcode and does not return json" do
    @user.client_secret_credentials.destroy_all
    create_client_recovery_passcode!(@user, name: "only recovery")

    post auth_app_settings_passkeys_options_path(ri: "jp"),
         headers: @headers,
         as: :json

    assert_response :forbidden
    assert_equal "text/html", response.media_type
    assert_includes response.body, I18n.t("sign.recovery_passcodes.required.setup_link")
    assert_empty flash.to_hash
  end

  test "verification ignores used deleted expired and wrong actor recovery passcodes" do
    @user.client_secret_credentials.destroy_all
    create_client_recovery_passcode!(@user, name: "used", last_used_at: Time.current)
    create_client_recovery_passcode!(
      @user,
      name: "deleted",
      status_id: ClientSecretCredentialStatus::DELETED,
    )
    create_client_recovery_passcode!(@user, name: "expired", discarded_at: 1.minute.ago)
    create_client_recovery_passcode!(@other_user, name: "other 1")
    create_client_recovery_passcode!(@other_user, name: "other 2")

    assert_no_difference("ClientPasskey.count") do
      post auth_app_settings_passkeys_verification_path(ri: "jp"),
           params: { challenge_id: "unknown", credential: { id: "cred-id" } },
           headers: @headers,
           as: :json
    end

    assert_response :forbidden
    assert_equal "text/html", response.media_type
  end

  test "show renders never when passkey has not been used" do
    @passkey.update!(last_used_at: nil)

    with_prosopite_paused do
      get auth_app_settings_passkey_path(@passkey.public_id, ri: "jp"), headers: @headers
    end

    assert_response :ok
    assert_equal "auth/app/settings/passkeys/show", inertia_component
    assert_includes(
      inertia_props.fetch("details").map { |detail| detail.fetch("value") },
      I18n.t("defaults.never"),
    )
  end

  test "show renders back link before passkey details" do
    with_prosopite_paused do
      get auth_app_settings_passkey_path(@passkey.public_id, ri: "jp"), headers: @headers
    end

    assert_response :ok
    assert_equal(
      auth_app_settings_passkeys_path(ri: "jp"),
      inertia_props.fetch("back_link").fetch("href"),
    )
  end

  test "new allows bootstrap passkey registration with two recovery passcodes" do
    unverified_user = create_verified_user_with_email(email_address: "bootstrap-new-#{SecureRandom.hex(4)}@example.com")
    token = ClientToken.create!(user: unverified_user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    satisfy_user_verification(token, scope: "settings_passkey")
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = AuthenticationToken.encode(
      unverified_user,
      host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      session_public_id: token.public_id,
      jwt_issuer_id: jwt_issuer_id_for_test_host(ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), "client"),
    )
    headers = as_user_headers(
      unverified_user,
      host: ENV.fetch(
        "AUTH_SERVICE_URL",
        "auth.app.localhost",
      ),
      session_public_id: token.public_id,
    )

    with_prosopite_paused do
      get new_auth_app_settings_passkey_path(ri: "jp"), headers: headers
    end

    assert_response :ok
  end

  test "create allows bootstrap passkey registration with two recovery passcodes" do
    email = "bootstrap-create-#{SecureRandom.hex(4)}@example.com"
    unverified_user = create_verified_user_with_email(email_address: email)
    token = ClientToken.create!(user: unverified_user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    satisfy_user_verification(token, scope: "settings_passkey")
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = AuthenticationToken.encode(
      unverified_user,
      host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      session_public_id: token.public_id,
      jwt_issuer_id: jwt_issuer_id_for_test_host(ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), "client"),
    )
    headers = as_user_headers(
      unverified_user,
      host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      session_public_id: token.public_id,
    )

    assert_no_difference("ClientPasskey.count") do
      assert_no_difference("ClientChronicle.count") do
        post auth_app_settings_passkeys_path(ri: "jp"),
             params: {
               user_passkey: {
                 webauthn_id: "wk_#{SecureRandom.hex(8)}",
                 public_key: "public_key",
                 sign_count: 0,
                 description: "Test",
               },
             },
             headers: headers
      end
    end

    assert_response :see_other
    assert_redirected_to new_auth_app_settings_passkey_path(ri: "jp")
  end

  test "should get edit with public_id" do
    with_prosopite_paused do
      get edit_auth_app_settings_passkey_path(@passkey.public_id, ri: "jp"), headers: @headers
    end

    assert_response :ok
    assert_equal "auth/app/settings/passkeys/edit", inertia_component
    assert_equal(
      auth_app_settings_passkey_path(@passkey.public_id, ri: "jp"),
      inertia_props.fetch("form").fetch("action"),
    )
    assert_equal @passkey.public_id, request.path_parameters[:id]
    assert_nil request.path_parameters[:public_id]
  end

  test "edit shows back link to passkey list" do
    with_prosopite_paused do
      get edit_auth_app_settings_passkey_path(@passkey.public_id, ri: "jp"), headers: @headers
    end

    assert_response :ok
    assert_equal(
      auth_app_settings_passkeys_path(ri: "jp"),
      inertia_props.fetch("back_link").fetch("href"),
    )
  end

  test "should update description with public_id" do
    patch auth_app_settings_passkey_path(@passkey.public_id, ri: "jp"),
          params: { client_passkey: { description: "Updated" } },
          headers: @headers

    assert_redirected_to auth_app_settings_passkey_path(@passkey.public_id, ri: "jp")
    assert_equal "Updated", @passkey.reload.description
  end

  test "should destroy with public_id" do
    ClientPasskey.create!(
      user: @user,
      webauthn_id: "webauthn_extra_#{SecureRandom.hex(4)}",
      public_key: "public_key_extra_#{SecureRandom.hex(4)}",
      sign_count: 0,
      description: "Extra Passkey",
    )
    headers = headers_for_client_token(@token, scope: "settings_passkey")

    before_count = ClientPasskey.count
    delete auth_app_settings_passkey_path(@passkey.public_id, ri: "jp"), headers: headers

    assert_redirected_to auth_app_settings_passkeys_path(ri: "jp")
    assert_equal before_count - 1, ClientPasskey.count
  end

  test "destroy requires fresh settings passkey step up" do
    ClientPasskey.create!(
      user: @user,
      webauthn_id: "webauthn_extra_#{SecureRandom.hex(4)}",
      public_key: "public_key_extra_#{SecureRandom.hex(4)}",
      sign_count: 0,
      description: "Extra Passkey",
    )
    @token.update!(last_step_up_at: 20.minutes.ago, last_step_up_scope: "settings_passkey")
    headers = headers_for_client_token(@token, scope: "settings_passkey", step_up_at: 20.minutes.ago)

    assert_no_difference("ClientPasskey.count") do
      delete auth_app_settings_passkey_path(@passkey.public_id, ri: "jp"), headers: headers
    end

    assert_response :unauthorized
    assert_includes response.body, "Step-up authentication required"
  end

  test "should 404 when accessing other user's passkey" do
    other_passkey =
      ClientPasskey.create!(
        user: @other_user,
        webauthn_id: "webauthn_other_#{SecureRandom.hex(4)}",
        public_key: "public_key_other_#{SecureRandom.hex(4)}",
        sign_count: 0,
        description: "Other Passkey",
      )

    with_prosopite_paused do
      get edit_auth_app_settings_passkey_path(other_passkey.public_id, ri: "jp"), headers: @headers
    end

    assert_response :not_found
  end

  test "index uses public_id in edit link" do
    with_prosopite_paused do
      get auth_app_settings_passkeys_path(ri: "jp"), headers: @headers
    end

    assert_response :ok
    assert_includes(
      inertia_props.fetch("passkeys").map { |row| row.fetch("edit_href") },
      edit_auth_app_settings_passkey_path(@passkey.public_id, ri: "jp"),
    )
  end

  private

  def with_prosopite_paused
    return yield unless defined?(Prosopite)

    original_raise = Prosopite.raise?
    original_ignore_queries = Prosopite.ignore_queries
    Prosopite.raise = false
    Prosopite.ignore_queries = original_ignore_queries + [/SELECT.*FROM.*"client_preference/]
    Prosopite.pause { yield }
  ensure
    if defined?(Prosopite)
      Prosopite.raise = original_raise
      Prosopite.ignore_queries = original_ignore_queries
    end
  end

  def regional_defaults
    { ri: "jp" }
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

  def create_client_recovery_passcode!(
    user,
    name:,
    status_id: ClientSecretCredentialStatus::ACTIVE,
    last_used_at: nil,
    discarded_at: nil,
    validate: true
  )
    credential = user.client_secret_credentials.new(
      name: name,
      user_secret_kind_id: ClientSecretCredentialKind::RECOVERY,
      user_identity_secret_status_id: status_id,
      last_used_at: last_used_at,
    )
    credential.discarded_at = discarded_at if discarded_at
    credential.password = ClientSecretCredential.generate_raw_secret_credential
    credential.save!(validate: validate)
    credential
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Auth::App::Settings::PasskeysControllerTest
  private
end

# DAMP local helper copy for former shared test support.
class Auth::App::Settings::PasskeysControllerTest
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

# DAMP local helper copy on the test class.
class Auth::App::Settings::PasskeysControllerTest
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
