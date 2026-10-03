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
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
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

    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    destination = nil
    JumpRtIssuer.stub(:call, ->(**args) { destination = args.fetch(:url); "opaque-jump" }) do
      RedirectsJumpGatewayUrl.stub(
        :call, ->(_code) { RedirectsTargetResult.ok(kind: :external, source: :test, value: destination) },
      ) do
        post base_org_sign_show_path, params: { ri: "jp" }
      end
    end

    assert_response :see_other
    entry_ref = Rack::Utils.parse_nested_query(URI.parse(destination).query).fetch("entry_ref")
    @flow = OperatorSignInFlow.find_by!(public_id: entry_ref)
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    get auth_org_sign_in_path, params: { entry_ref: entry_ref, ri: "jp" }
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_org_sign_in_path, params: { entry_ref: entry_ref, authenticity_token: csrf, ri: "jp" }

    assert_response :see_other
  end

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "the entry page is identifier-first and says what the resulting session cannot do" do
    get new_auth_org_sign_in_emergency_passkey_url(ri: "jp")

    assert_response :success
    assert_equal "auth/org/sign/in/emergency/passkeys/new", inertia_component

    panel = inertia_props.fetch("panel")

    assert_equal "identifier", panel.fetch("identifier_param")
    assert_equal 16, panel.fetch("field").fetch("min_length")
    assert_equal(
      auth_org_sign_in_emergency_passkey_options_path(ri: "jp"),
      panel.fetch("options_url"),
    )
    assert_equal(
      auth_org_sign_in_emergency_passkey_verification_path(ri: "jp"),
      panel.fetch("verification_url"),
    )
    assert_equal(
      I18n.t("sign.org.authentication.emergency.passkey.new.restricted_mode_notice"),
      inertia_props.fetch("restricted_mode_notice"),
    )
  end

  test "emergency access needs no entra stage and binds its challenge to its own purpose" do
    challenge_id = issue_emergency_challenge!
    challenge = session[:passkey_challenges].fetch(challenge_id)

    assert_equal "emergency_sign_in", challenge["purpose"]
    assert_equal "org:#{@staff.id}", challenge["actor_global_key"]
  end

  test "an emergency assertion records emergency evidence without issuing a root session on Auth" do
    challenge_id = issue_emergency_challenge!
    verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post auth_org_sign_in_emergency_passkey_verification_url(ri: "jp"), params: verification_params(challenge_id)
    end

    assert_response :ok
    assert_equal "ok", response.parsed_body["status"]

    assert_equal "emergency", @flow.reload.authentication_context
    assert_equal "passkey", @flow.authentication_method
    assert_equal 0, OperatorToken.where(staff_id: @staff.id).count
    assert_nil response.parsed_body["access_token"]
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
  end

  test "Base finalizes emergency evidence as an emergency session with narrowed scopes using a stubbed assertion" do
    challenge_id = issue_emergency_challenge!
    verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post auth_org_sign_in_emergency_passkey_verification_url(ri: "jp"), params: verification_params(challenge_id)
    end

    get response.parsed_body.fetch("redirect_url")
    follow_redirect!

    assert_response :success
    post auth_org_sign_handoff_path, params: { ri: "jp" }

    assert_response :success
    result = response.parsed_body.at_css('input[name="result"]')["value"]

    assert_equal 0, OperatorToken.where(staff_id: @staff.id).count
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    post base_org_sign_completion_path,
         params: { result: result, transaction_ref: @flow.public_id, ri: "jp" },
         headers: { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_STAFF_URL")}", "Sec-Fetch-Site" => "same-site" }

    assert_response :see_other
    token = @flow.reload.token

    assert_equal "emergency", token.authentication_context
    assert_predicate token, :emergency_authentication_context?
    claims = AuthenticationToken.decode(
      cookies[AuthenticationBase::ACCESS_COOKIE_KEY], host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
                                                      resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )

    assert_equal "emergency", claims.fetch(AuthenticationContextValue::CLAIM)
    scopes = AuthorizationTokenClaims.scopes(claims)

    assert_includes scopes, "read:org"
    assert_not_includes scopes, "write:org", "an emergency session must not carry org write scope"
  end

  test "a normal sign-in challenge is rejected by the emergency verifier" do
    complete_org_entra_first_stage!(@staff)
    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: {}

    assert_response :ok
    normal_challenge_id = response.parsed_body.fetch("challenge_id")

    post auth_org_sign_in_emergency_passkey_verification_url(ri: "jp"),
         params: verification_params(normal_challenge_id)

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.webauthn.challenge_invalid")
    assert_equal 0, OperatorToken.where(staff_id: @staff.id).count
  end

  test "an emergency challenge is rejected by the normal verifier" do
    emergency_challenge_id = issue_emergency_challenge!
    complete_org_entra_first_stage!(@staff)

    post auth_org_sign_in_passkey_verification_url(ri: "jp"), params: verification_params(emergency_challenge_id)

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.webauthn.challenge_invalid")
    assert_equal 0, OperatorToken.where(staff_id: @staff.id).count
  end

  test "an operator who may not sign in is refused without becoming distinguishable at the options step" do
    @staff.update!(status_id: OperatorStatus::ACTIVE, withdrawn_at: Time.current)

    post auth_org_sign_in_emergency_passkey_options_url(ri: "jp"), params: { identifier: @staff.public_id }

    assert_response :ok
    assert_equal(
      4,
      response.parsed_body.dig("options", "allowCredentials").size,
      "an ineligible operator must be indistinguishable from an unknown one",
    )

    challenge_id = response.parsed_body.fetch("challenge_id")
    verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post auth_org_sign_in_emergency_passkey_verification_url(ri: "jp"), params: verification_params(challenge_id)
    end

    assert_response :unauthorized
    assert_equal 0, OperatorToken.where(staff_id: @staff.id).count
  end

  test "an eligible operator loses emergency access the moment the policy stops allowing it" do
    challenge_id = issue_emergency_challenge!
    @staff.update!(withdrawn_at: Time.current)
    verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post auth_org_sign_in_emergency_passkey_verification_url(ri: "jp"), params: verification_params(challenge_id)
    end

    assert_response :unauthorized
    assert_equal 0, OperatorToken.where(staff_id: @staff.id).count
  end

  test "an authenticated operator cannot enter emergency access" do
    staff = operators(:one)

    get new_auth_org_sign_in_emergency_passkey_url(ri: "jp"),
        headers: as_staff_headers(staff, host: ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost"))

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "an authenticated operator cannot run the emergency ceremony endpoints" do
    staff = operators(:one)
    headers = as_staff_headers(staff, host: ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost"))

    post auth_org_sign_in_emergency_passkey_options_url(ri: "jp"),
         params: { identifier: staff.public_id }, headers: headers

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil session[:passkey_challenges]
  end

  private

  def issue_emergency_challenge!
    post(auth_org_sign_in_emergency_passkey_options_url(ri: "jp"), params: { identifier: @staff.public_id })

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
      host: ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost"),
      resource_type: "operator",
      jwt_issuer_id: "surface:AUTH_ORG",
    )
  end
end
