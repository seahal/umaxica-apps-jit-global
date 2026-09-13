# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"

class Auth::Com::Settings::PasskeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    host! @host
    @origin_headers = { "HTTP_ORIGIN" => "http://#{@host}", "Origin" => "http://#{@host}" }.freeze
    @visitor = create_verified_visitor_with_email(email_address: "com_passkey_config@example.com")
    @visitor.visitor_secret_credentials.destroy_all
    create_visitor_recovery_passcode!(@visitor, name: "recovery 1")
    create_visitor_recovery_passcode!(@visitor, name: "recovery 2")
    @visitor.visitor_telephones.create!(
      number: "+819044444444",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @headers = as_visitor_headers(@visitor, host: @host)
    @token = VisitorToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    satisfy_visitor_verification(@token)
    mark_token_step_up_satisfied_for_test(@token, scope: "settings_passkey")

    @passkey = VisitorPasskey.create!(
      visitor: @visitor,
      webauthn_id: Base64.urlsafe_encode64("com_existing_credential", padding: false),
      public_key: "public_key_#{SecureRandom.hex(4)}",
      sign_count: 0,
      description: "My Passkey",
      status_id: VisitorPasskeyStatus::ACTIVE,
    )

    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "unauthenticated passkey settings requests start login handoff" do
    get auth_com_settings_passkeys_path(ri: "jp"), headers: browser_headers.merge(host_headers(@host))

    assert_response :redirect
    assert_oidc_authorize_redirect(
      jump_rt_url_from_location(response.location),
      host: Rails.configuration.x.boot_config.fetch(:hosts).base_corporate.host,
      client_id: "sign-rp",
    )
  end

  test "index renders sign settings passkeys" do
    get auth_com_settings_passkeys_path(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, @passkey.description
  end

  test "options returns challenge and options" do
    post auth_com_settings_passkeys_options_path(ri: "jp"),
         headers: @headers.merge(@origin_headers)

    assert_response :ok
    assert_not_nil response.parsed_body["challenge_id"]
  end

  test "options denies with fewer than two unused usable recovery passcodes" do
    @visitor.visitor_secret_credentials.destroy_all
    create_visitor_recovery_passcode!(@visitor, name: "only recovery")

    post auth_com_settings_passkeys_options_path(ri: "jp"), headers: @headers.merge(@origin_headers), as: :json

    assert_response :forbidden
    assert_equal "text/html", response.media_type
    assert_includes response.body, base_com_identity_url(
      ri: "jp",
      host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
    )
  end

  test "verification creates passkey on success" do
    post auth_com_settings_passkeys_options_path(ri: "jp"),
         headers: @headers.merge(@origin_headers)
    challenge_id = response.parsed_body["challenge_id"]
    cookie_header = response_set_cookie_lines.map { |line| line.split(";", 2).first }.join("; ")

    mock_credential = Object.new
    mock_credential.define_singleton_method(:id) { "new_webauthn_id" }
    mock_credential.define_singleton_method(:public_key) { "new_public_key" }
    mock_credential.define_singleton_method(:sign_count) { 1 }
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    registration_context = Struct.new(
      :webauthn_id, :sign_count, :aaguid, :transports,
      :backup_eligible, :backup_state, :authenticator_attachment,
    ).new(
      "new_webauthn_id", 1,
    )
    Webauthn::RegistrationVerifier.stub(:verify!, registration_context) do
      WebAuthn::Credential.stub(:from_create, mock_credential) do
        assert_difference("VisitorPasskey.count", 1) do
          assert_difference(-> { @visitor.reload.visitor_secret_credentials.count }, 8) do
            post auth_com_settings_passkeys_verification_path(ri: "jp"),
                 params: {
                   challenge_id: challenge_id,
                   credential: {
                     id: "new_webauthn_id",
                     response: { clientDataJSON: "e30=", attestationObject: "e30=" },
                   },
                   description: "New Passkey",
                 },
                 headers: @headers.merge(@origin_headers).merge("Cookie" => cookie_header)
          end
        end
      end
    end

    assert_response :created
    assert_equal "ok", response.parsed_body["status"]
    assert_includes response.parsed_body["redirect_url"], "/identity"
  end

  # The registration ceremony maps each failure class to its own answer, and none of
  # them may leave a credential behind. Only the happy path and the unknown-challenge
  # path were exercised before.
  test "verification answers 422 when the assertion does not verify" do
    post auth_com_settings_passkeys_options_path(ri: "jp"), headers: @headers.merge(@origin_headers)
    challenge_id = response.parsed_body["challenge_id"]
    cookie_header = response_set_cookie_lines.map { |line| line.split(";", 2).first }.join("; ")

    verifier_failure =
      lambda do |**|
        raise Webauthn::RegistrationVerifier::VerificationError, "assertion did not verify"
      end

    Webauthn::RegistrationVerifier.stub(:verify!, verifier_failure) do
      assert_no_difference("VisitorPasskey.count") do
        post auth_com_settings_passkeys_verification_path(ri: "jp"),
             params: {
               challenge_id: challenge_id,
               credential: { id: "x", response: { clientDataJSON: "e30=", attestationObject: "e30=" } },
             },
             headers: @headers.merge(@origin_headers).merge("Cookie" => cookie_header)
      end
    end

    assert_response :unprocessable_content
    assert_equal I18n.t("errors.webauthn.verification_failed"), response.parsed_body.fetch("error")
  end

  test "verification succeeds without recovery passcodes on bootstrap and tops up to ten" do
    visitor = create_verified_visitor_with_email(email_address: "com-bootstrap-#{SecureRandom.hex(4)}@example.com")
    visitor.visitor_telephones.create!(
      number: "+819055555555",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    token = VisitorToken.create!(visitor: visitor, visitor_token_status_id: VisitorTokenStatus::ACTIVE)
    satisfy_visitor_verification(token)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_passkey")
    headers = as_visitor_headers(visitor, host: @host, session_public_id: token.public_id)

    mock_credential = Object.new
    mock_credential.define_singleton_method(:id) { "bootstrap_new_webauthn_id" }
    mock_credential.define_singleton_method(:public_key) { "bootstrap_new_public_key" }
    mock_credential.define_singleton_method(:sign_count) { 1 }
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    registration_context = Struct.new(
      :webauthn_id, :sign_count, :aaguid, :transports,
      :backup_eligible, :backup_state, :authenticator_attachment,
    ).new(
      "bootstrap_new_webauthn_id", 1,
    )
    Webauthn::RegistrationVerifier.stub(:verify!, registration_context) do
      WebAuthn::Credential.stub(:from_create, mock_credential) do
        post auth_com_settings_passkeys_options_path(ri: "jp"),
             headers: headers.merge(@origin_headers)
        challenge_id = response.parsed_body["challenge_id"]
        cookie_header = response_set_cookie_lines.map { |line| line.split(";", 2).first }.join("; ")

        assert_difference("VisitorPasskey.count", 1) do
          assert_difference(-> { visitor.reload.visitor_secret_credentials.count }, 10) do
            post auth_com_settings_passkeys_verification_path(ri: "jp"),
                 params: {
                   challenge_id: challenge_id,
                   credential: {
                     id: "bootstrap_new_webauthn_id",
                     response: { clientDataJSON: "e30=", attestationObject: "e30=" },
                   },
                   description: "Bootstrap Passkey",
                 },
                 headers: headers.merge(@origin_headers).merge("Cookie" => cookie_header)
          end
        end
      end
    end

    assert_response :created
    assert_includes response.parsed_body["redirect_url"], "/identity"
  end

  test "create json returns registration ceremony handoff" do
    assert_no_difference("VisitorPasskey.count") do
      post auth_com_settings_passkeys_path(ri: "jp", format: :json), headers: @headers
    end

    assert_response :accepted
    assert_equal "registration_ceremony_required", response.parsed_body["status"]
    assert_equal new_auth_com_settings_passkey_path(ri: "jp"), response.parsed_body["redirect_path"]
  end

  test "update accepts visitor passkey form params" do
    patch auth_com_settings_passkey_path(@passkey.public_id, ri: "jp"),
          params: { visitor_passkey: { description: "Updated Passkey" } },
          headers: @headers

    assert_redirected_to auth_com_settings_passkey_path(@passkey.public_id, ri: "jp")
    assert_equal "Updated Passkey", @passkey.reload.description
  end

  test "destroy removes visitor passkey on sign settings authority" do
    VisitorPasskey.create!(
      visitor: @visitor,
      webauthn_id: "test_webauthn_id_destroy_extra",
      external_id: "test_external_id_destroy_extra",
      public_key: "test_public_key_destroy_extra",
      description: "Extra Passkey",
      status_id: VisitorPasskeyStatus::ACTIVE,
      uv_verified_at: Time.current,
    )
    headers = headers_for_visitor_token(@token, scope: "settings_passkey")

    assert_difference("VisitorPasskey.count", -1) do
      delete auth_com_settings_passkey_path(@passkey.public_id, ri: "jp"), headers: headers
    end

    assert_redirected_to auth_com_settings_passkeys_path(ri: "jp")
  end

  test "destroy requires fresh settings passkey step up" do
    VisitorPasskey.create!(
      visitor: @visitor,
      webauthn_id: "test_webauthn_id_destroy_stale_extra",
      external_id: "test_external_id_destroy_stale_extra",
      public_key: "test_public_key_destroy_stale_extra",
      description: "Extra Passkey",
      status_id: VisitorPasskeyStatus::ACTIVE,
    )
    headers = headers_for_visitor_token(@token, scope: "settings_passkey", step_up_at: 20.minutes.ago)

    assert_no_difference("VisitorPasskey.count") do
      delete auth_com_settings_passkey_path(@passkey.public_id, ri: "jp"), headers: headers
    end

    assert_response :unauthorized
    assert_includes response.body, "Step-up authentication required"
  end

  test "show renders the details of a passkey the visitor owns" do
    get auth_com_settings_passkey_path(@passkey.public_id, ri: "jp"), headers: @headers

    assert_response :success
    details = inertia_props.fetch("details").to_h { |detail| [detail.fetch("key"), detail.fetch("value")] }

    assert_equal @passkey.description, details.fetch("description")
    assert_equal @passkey.sign_count.to_s, details.fetch("sign_count")
  end

  test "new starts a registration ceremony and exposes the ceremony endpoints" do
    get new_auth_com_settings_passkey_path(ri: "jp"), headers: @headers

    assert_response :success
    panel = inertia_props.fetch("panel")

    assert_equal auth_com_settings_passkeys_options_path(ri: "jp"), panel.fetch("options_url")
    assert_equal auth_com_settings_passkeys_verification_path(ri: "jp"), panel.fetch("verification_url")
  end

  test "edit renders the rename form for a passkey the visitor owns" do
    get edit_auth_com_settings_passkey_path(@passkey.public_id, ri: "jp"), headers: @headers

    assert_response :success
    assert_equal auth_com_settings_passkey_path(@passkey.public_id, ri: "jp"), inertia_props.fetch("action")
    assert_equal @passkey.description, inertia_props.fetch("description")
  end

  test "show answers not found for a passkey owned by another visitor" do
    other_visitor = create_verified_visitor_with_email(email_address: "com_other_passkey_owner@example.com")
    other_passkey = VisitorPasskey.create!(
      visitor: other_visitor,
      webauthn_id: Base64.urlsafe_encode64("com_other_credential", padding: false),
      public_key: "public_key_#{SecureRandom.hex(4)}",
      sign_count: 0,
      description: "Someone else's passkey",
      status_id: VisitorPasskeyStatus::ACTIVE,
    )

    get auth_com_settings_passkey_path(other_passkey.public_id, ri: "jp"), headers: @headers

    assert_response :not_found
  end

  test "the registration ceremony issues a challenge and creates the passkey on a verified assertion" do
    post auth_com_settings_passkeys_options_path(ri: "jp"), headers: @headers

    assert_response :ok
    challenge_id = response.parsed_body["challenge_id"]

    assert_predicate challenge_id, :present?

    credential = Object.new
    credential.define_singleton_method(:id) { "com_settings_new_webauthn_id" }
    credential.define_singleton_method(:public_key) { "com_settings_new_public_key" }
    credential.define_singleton_method(:sign_count) { 1 }
    credential.define_singleton_method(:verify) { |*_args| true }
    registration_context = Struct.new(
      :webauthn_id, :sign_count, :aaguid, :transports, :backup_eligible, :backup_state,
      :authenticator_attachment,
    ).new("com_settings_new_webauthn_id", 1)

    Webauthn::RegistrationVerifier.stub(:verify!, registration_context) do
      WebAuthn::Credential.stub(:from_create, credential) do
        assert_difference("VisitorPasskey.count", 1) do
          post auth_com_settings_passkeys_verification_path(ri: "jp"), params: {
            challenge_id: challenge_id,
            credential: {
              id: "com_settings_new_webauthn_id",
              response: { clientDataJSON: "e30=", attestationObject: "e30=" },
            },
            description: "New Corporate Passkey",
          }, headers: @headers
        end
      end
    end

    assert_response :created
    assert_equal "ok", response.parsed_body["status"]
    assert_predicate response.parsed_body["redirect_url"], :present?
  end

  test "the registration ceremony refuses an assertion with no challenge id" do
    post auth_com_settings_passkeys_verification_path(ri: "jp"), params: {
      credential: { id: "x", response: { clientDataJSON: "e30=", attestationObject: "e30=" } },
    }, headers: @headers

    assert_response :bad_request
  end

  test "the registration ceremony refuses a challenge id it never issued" do
    assert_no_difference("VisitorPasskey.count") do
      post auth_com_settings_passkeys_verification_path(ri: "jp"), params: {
        challenge_id: "never-issued",
        credential: { id: "x", response: { clientDataJSON: "e30=", attestationObject: "e30=" } },
      }, headers: @headers
    end

    assert_response :bad_request
  end

  test "the registration ceremony rejects a webauthn id that is already registered" do
    post auth_com_settings_passkeys_options_path(ri: "jp"), headers: @headers
    challenge_id = response.parsed_body["challenge_id"]
    credential = Object.new
    credential.define_singleton_method(:id) { @passkey.webauthn_id }
    credential.define_singleton_method(:public_key) { "duplicate_public_key" }
    credential.define_singleton_method(:sign_count) { 1 }
    credential.define_singleton_method(:verify) { |*_args| true }
    registration_context = Struct.new(
      :webauthn_id, :sign_count, :aaguid, :transports, :backup_eligible, :backup_state,
      :authenticator_attachment,
    ).new(@passkey.webauthn_id, 1)

    Webauthn::RegistrationVerifier.stub(:verify!, registration_context) do
      WebAuthn::Credential.stub(:from_create, credential) do
        assert_no_difference("VisitorPasskey.count") do
          post auth_com_settings_passkeys_verification_path(ri: "jp"), params: {
            challenge_id: challenge_id,
            credential: {
              id: @passkey.webauthn_id,
              response: { clientDataJSON: "e30=", attestationObject: "e30=" },
            },
            description: "Duplicate",
          }, headers: @headers
        end
      end
    end

    assert_response :unprocessable_content
  end

  test "a failed turnstile challenge refuses the registration options as JSON" do
    TurnstileVerifierStub.challenge_response = { "success" => false }

    post auth_com_settings_passkeys_options_path(ri: "jp"),
         headers: @headers.merge(@origin_headers), as: :json

    assert_response :unprocessable_content
    assert_equal I18n.t("turnstile_error"), response.parsed_body.fetch("error")
    assert_nil response.parsed_body["challenge_id"]
  end

  test "a failed turnstile challenge sends a document request back to the passkey list" do
    TurnstileVerifierStub.challenge_response = { "success" => false }

    post auth_com_settings_passkeys_options_path(ri: "jp"),
         headers: @headers.merge(@origin_headers)

    assert_response :see_other
    assert_redirected_to auth_com_settings_passkeys_path(ri: "jp")
  end

  private

  def headers_for_visitor_token(token, scope:, step_up_at: Time.current)
    Actor.clear if defined?(Actor)
    mark_settings_step_up_satisfied!(token, scope: scope, at: step_up_at)
    access_token = AuthenticationToken.encode(
      token.visitor,
      host: @host,
      session_public_id: token.public_id,
      resource_type: "visitor",
      jwt_issuer_id: jwt_issuer_id_for_test_host(@host, "visitor"),
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
      last_step_up_audience: "step_up:com",
      updated_at: Time.current,
    )
  end

  def create_visitor_recovery_passcode!(visitor, name:, last_used_at: nil)
    credential = visitor.visitor_secret_credentials.new(
      name: name,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::RECOVERY,
      visitor_secret_credential_status_id: VisitorSecretCredentialStatus::ACTIVE,
      last_used_at: last_used_at,
    )
    credential.password = VisitorSecretCredential.generate_raw_secret_credential
    credential.save!
    credential
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Auth::Com::Settings::PasskeysControllerTest
  private
end

# DAMP local helper copy for former shared test support.
class Auth::Com::Settings::PasskeysControllerTest
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
class Auth::Com::Settings::PasskeysControllerTest
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
    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
      }",
    )
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
    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }",
    )
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
    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor")
      }",
    )
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
    if defined?(VisitorSecretCredentialStatus)
      VisitorSecretCredentialStatus::DEFAULTS.each do |id|
        VisitorSecretCredentialStatus.find_or_create_by!(id: id)
      end
    end
    return unless defined?(VisitorSecretCredentialKind)

    VisitorSecretCredentialKind::DEFAULTS.each do |id|
      VisitorSecretCredentialKind.find_or_create_by!(id: id)
    end
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
