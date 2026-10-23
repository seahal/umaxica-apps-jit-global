# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

# Emergency Access (Restricted Mode): the org-only, Entra-free, passkey-only
# sign-in.
#
# It uses the operator's ordinary registered passkeys and the ordinary shared
# WebAuthn machinery. What it produces is different: a session whose
# authentication context is recorded as `emergency`, carried in the access
# token, and never convertible into a normal one.
class Auth::Org::Sign::In::Emergency::PasskeysControllerTest < ActionDispatch::IntegrationTest
  include OrgEntraFirstStageHelper

  fixtures :operators, :operator_statuses, :operator_passkeys, :operator_passkey_statuses,
           :operator_token_binding_methods, :operator_token_kinds, :operator_token_statuses,
           :operator_token_dbsc_statuses

  setup do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }

    @staff = operators(:one)
    @staff.update!(status_id: OperatorStatus::ACTIVE)
    OperatorToken.where(staff_id: @staff.id).delete_all

    @staff_passkey = OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: Base64.urlsafe_encode64("emergency_passkey_id_1234", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "emergency_key",
      description: "Emergency Key",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    issuance = OidcTestEntry.issue!(
      surface: "org",
      intent: "sign_in",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "org", reference: issuance.reference)
    auth_session, raw_sid = binding.class.auth_admission_session_class.issue!
    binding.attach_auth_session!(auth_session: auth_session, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "org", entry_ref: issuance.reference, nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      ),
    )
    https!
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    store_raw_cookies(
      cookies,
      "#{cookie_name}=#{Rack::Utils.escape(raw_sid)}", URI.parse("https://#{ENV.fetch("PUBLIC_AUTH_STAFF_URL")}/"),
    )
    get auth_org_sign_in_path, params: { entry_ref: issuance.reference, ri: "jp" }
    form = response.parsed_body.at_css("form")
    fields = form.css("input[type='hidden']").to_h { |input| [input["name"], input["value"]] }
    post form["action"], params: fields, headers: {
      "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_STAFF_URL")}", "Sec-Fetch-Site" => "same-origin",
    }

    assert_response :see_other
  end

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "the entry page is identifier-first and says what the resulting session cannot do" do
    get new_auth_org_sign_in_emergency_passkey_url(ri: "jp", **org_emergency_binding_params)

    assert_response :success
    assert_equal "auth/org/sign/in/emergency/passkeys/new", inertia_component

    panel = inertia_props.fetch("panel")

    assert_equal "identifier", panel.fetch("identifier_param")
    assert_equal 16, panel.fetch("field").fetch("min_length")
    options_uri = URI.parse(panel.fetch("options_url"))
    verification_uri = URI.parse(panel.fetch("verification_url"))

    assert_equal "/sign/in/emergency/passkey/options", options_uri.path
    assert_equal "/sign/in/emergency/passkey/verification", verification_uri.path
    assert_equal "jp", Rack::Utils.parse_nested_query(options_uri.query).fetch("ri")
    assert_equal "jp", Rack::Utils.parse_nested_query(verification_uri.query).fetch("ri")
    # An OIDC-parent primary phase has no sign-in flow, so the endpoints carry no phase binding.
    assert_nil Rack::Utils.parse_nested_query(options_uri.query)["fb"]
    assert_nil Rack::Utils.parse_nested_query(verification_uri.query)["fb"]
    assert_equal(
      I18n.t("sign.org.authentication.emergency.passkey.new.restricted_mode_notice"),
      inertia_props.fetch("restricted_mode_notice"),
    )
  end

  test "emergency access needs no entra stage and binds its challenge to its own purpose" do
    challenge_id = issue_emergency_challenge!
    challenge = session[:passkey_challenges].fetch(challenge_id)

    assert_equal "emergency_sign_in", challenge["purpose"]
    assert_equal "org:#{@staff.public_id}", challenge["actor_global_key"]
  end

  test "repeated emergency options disclose no credential ids for eligible ineligible or unknown operators" do
    selections = [@staff.public_id, @staff.public_id, "z" * 16]
    @staff.reload.update!(withdrawn_at: Time.current)
    selections << @staff.public_id
    @staff.update!(withdrawn_at: nil)

    binding_sizes = []
    selections.each_with_index do |identifier, index|
      @staff.update!(withdrawn_at: Time.current) if index == 3
      post auth_org_sign_in_emergency_passkey_options_url(ri: "jp", **org_emergency_binding_params),
           params: { identifier: identifier }

      assert_response :ok
      assert_empty response.parsed_body.fetch("options").fetch("allowCredentials")
      assert_not_includes response.body, @staff_passkey.webauthn_id
      assert_nil response.headers["Location"]
      challenge = session[:passkey_challenges].fetch(response.parsed_body.fetch("challenge_id"))
      actor_binding = challenge.fetch("actor_global_key")
      binding_sizes << actor_binding.bytesize
      expected = (index < 2) ? "org:#{@staff.public_id}" : "org:!!!!!!!!!!!!!!!!"

      assert_equal expected, actor_binding
    end

    assert_equal [20], binding_sizes.uniq
    assert_equal 0, OperatorToken.where(staff_id: @staff.id).count
  end

  test "an emergency assertion records emergency evidence without issuing a root session on Auth" do
    challenge_id = issue_emergency_challenge!
    verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post auth_org_sign_in_emergency_passkey_verification_url(
        ri: "jp", **org_emergency_binding_params,
      ), params: verification_params(challenge_id)
    end

    assert_response :ok
    assert_equal "ok", response.parsed_body["status"]

    flow = OperatorSignInFlow.where(principal_id: @staff.id).recent_first.first!

    assert_equal "standby", flow.authentication_context
    assert_equal "passkey", flow.authentication_method
    assert_equal 0, OperatorToken.where(staff_id: @staff.id).count
    assert_nil response.parsed_body["access_token"]
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
  end

  test "a normal sign-in challenge is rejected by the emergency verifier" do
    begin
      admission_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      admission_sid = cookies["__Host-auth_sid"].presence || cookies["auth_sid"].presence
      admission_session = OperatorAuthCeremonySession.find_active_by_raw_sid(admission_sid) if admission_sid
      unless admission_session&.admitted? && admission_session.admission_purpose == "authentication_handoff"
        admission_nonce = SecureRandom.urlsafe_base64(32)
        admission = OidcTestEntry.issue!(
          surface: "org", intent: "sign_in", base_browser_nonce: admission_nonce, base_token: nil,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "org",
          reference: admission.reference,
        )
        admission_session, admission_sid = OperatorAuthCeremonySession.issue!
        admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: "org",
            entry_ref: admission.reference,
            nonce: admission_nonce,
          ),
        )
        host!(admission_host)
        https!
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        cookies.delete("auth_sid")
        cookies.delete("__Host-auth_sid")
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_sid)}", URI.parse("https://#{admission_host}/"),
        )
        get auth_org_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
        admission_form = response.parsed_body.at_css("form")
        raise RuntimeError, "Auth admission continuation is missing" unless admission_form

        admission_fields = admission_form.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
        post admission_form["action"], params: admission_fields,
                                       headers: {
                                         "Origin" => "https://#{admission_host}",
                                         "Sec-Fetch-Site" => "same-origin",
                                       }

        assert_response :see_other
      end
      complete_org_entra_first_stage!(@staff)
    end
    post auth_org_sign_in_passkey_options_url(ri: "jp", **org_normal_sign_in_binding_params), params: {}

    assert_response :ok
    normal_challenge_id = response.parsed_body.fetch("challenge_id")

    post auth_org_sign_in_emergency_passkey_verification_url(ri: "jp", **org_emergency_binding_params),
         params: verification_params(normal_challenge_id)

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.webauthn.challenge_invalid")
    assert_equal 0, OperatorToken.where(staff_id: @staff.id).count
  end

  test "an emergency challenge is rejected by the normal verifier" do
    emergency_challenge_id = issue_emergency_challenge!
    begin
      admission_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      admission_sid = cookies["__Host-auth_sid"].presence || cookies["auth_sid"].presence
      admission_session = OperatorAuthCeremonySession.find_active_by_raw_sid(admission_sid) if admission_sid
      unless admission_session&.admitted? && admission_session.admission_purpose == "authentication_handoff"
        admission_nonce = SecureRandom.urlsafe_base64(32)
        admission = OidcTestEntry.issue!(
          surface: "org", intent: "sign_in", base_browser_nonce: admission_nonce, base_token: nil,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "org",
          reference: admission.reference,
        )
        admission_session, admission_sid = OperatorAuthCeremonySession.issue!
        admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: "org",
            entry_ref: admission.reference,
            nonce: admission_nonce,
          ),
        )
        host!(admission_host)
        https!
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        cookies.delete("auth_sid")
        cookies.delete("__Host-auth_sid")
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_sid)}", URI.parse("https://#{admission_host}/"),
        )
        get auth_org_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
        admission_form = response.parsed_body.at_css("form")
        raise RuntimeError, "Auth admission continuation is missing" unless admission_form

        admission_fields = admission_form.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
        post admission_form["action"], params: admission_fields,
                                       headers: {
                                         "Origin" => "https://#{admission_host}",
                                         "Sec-Fetch-Site" => "same-origin",
                                       }

        assert_response :see_other
      end
      complete_org_entra_first_stage!(@staff)
    end

    post auth_org_sign_in_passkey_verification_url(
      ri: "jp", **org_normal_sign_in_binding_params,
    ), params: verification_params(emergency_challenge_id)

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.webauthn.challenge_invalid")
    assert_equal 0, OperatorToken.where(staff_id: @staff.id).count
  end

  test "an operator who may not sign in is refused without becoming distinguishable at the options step" do
    @staff.reload.update!(status_id: OperatorStatus::ACTIVE, withdrawn_at: Time.current)

    post auth_org_sign_in_emergency_passkey_options_url(
      ri: "jp", **org_emergency_binding_params,
    ), params: { identifier: @staff.public_id }

    assert_response :ok
    assert_equal(
      0,
      response.parsed_body.dig("options", "allowCredentials").size,
      "an ineligible operator must be indistinguishable from an unknown one",
    )

    challenge_id = response.parsed_body.fetch("challenge_id")
    verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post auth_org_sign_in_emergency_passkey_verification_url(
        ri: "jp", **org_emergency_binding_params,
      ), params: verification_params(challenge_id)
    end

    assert_response :unauthorized
    assert_equal 0, OperatorToken.where(staff_id: @staff.id).count
  end

  test "an eligible operator loses emergency access the moment the policy stops allowing it" do
    challenge_id = issue_emergency_challenge!
    @staff.reload.update!(withdrawn_at: Time.current)
    verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post auth_org_sign_in_emergency_passkey_verification_url(
        ri: "jp", **org_emergency_binding_params,
      ), params: verification_params(challenge_id)
    end

    assert_response :unauthorized
    assert_equal 0, OperatorToken.where(staff_id: @staff.id).count
  end

  test "an authenticated operator cannot enter emergency access" do
    staff = operators(:one)

    get new_auth_org_sign_in_emergency_passkey_url(ri: "jp"),
        headers: as_staff_headers(staff, host: ENV.fetch("PUBLIC_AUTH_STAFF_URL"))

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "an authenticated operator cannot run the emergency ceremony endpoints" do
    staff = operators(:one)
    headers = as_staff_headers(staff, host: ENV.fetch("PUBLIC_AUTH_STAFF_URL"))

    post auth_org_sign_in_emergency_passkey_options_url(ri: "jp", **org_emergency_binding_params),
         params: { identifier: staff.public_id }, headers: headers

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil session[:passkey_challenges]
  end

  private

  # An OIDC-parent primary phase has no sign-in flow, so no phase binding is sent.
  def org_emergency_binding_params = {}

  def issue_emergency_challenge!
    post(
      auth_org_sign_in_emergency_passkey_options_url(ri: "jp", **org_emergency_binding_params),
      params: { identifier: @staff.public_id },
    )

    assert_response :ok
    response.parsed_body.fetch("challenge_id")
  end

  def verification_params(challenge_id, credential_id: @staff_passkey.webauthn_id)
    {
      challenge_id: challenge_id,
      credential: {
        id: credential_id,
        response: { clientDataJSON: "e30=", authenticatorData: "e30=", signature: "sig", userHandle: "h" },
      },
    }
  end

  def decoded_access_token(token)
    AuthenticationToken.decode(
      token,
      host: ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
      resource_type: "operator",
      jwt_issuer_id: "surface:AUTH_ORG",
    )
  end
end
