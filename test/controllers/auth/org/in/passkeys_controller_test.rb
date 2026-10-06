# typed: false
# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "base64"

# The passkey stage of normal org sign-in.
#
# Every test here starts from a completed Entra ceremony, because that is now
# the only way to reach this endpoint: Entra identifies the operator, and this
# stage authenticates them. The identifier-first ceremony that used to live at
# these URLs is Emergency Access, and its tests live in
# test/controllers/auth/org/in/emergency/passkeys_controller_test.rb.
class Auth::Org::Sign::In::PasskeysControllerTest < ActionDispatch::IntegrationTest
  include OrgEntraFirstStageHelper

  fixtures :operators, :operator_statuses, :operator_passkeys, :operator_passkey_statuses

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
      webauthn_id: Base64.urlsafe_encode64("staff_login_id_bytes_12345", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "staff_login_key",
      description: "Staff Login Key",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
  end

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "the entra callback establishes no session and hands the browser to the passkey stage" do
    complete_org_entra_first_stage!(@staff)

    assert_redirected_to new_auth_org_sign_in_passkey_path(ri: "jp")
    assert_equal 0, OperatorToken.where(staff_id: @staff.id).count
  end

  test "should get new" do
    complete_org_entra_first_stage!(@staff)

    get new_auth_org_sign_in_passkey_url(ri: "jp")

    assert_response :success
    assert_equal "auth/org/sign/in/passkeys/new", inertia_component

    panel = inertia_props.fetch("panel")

    # The Entra transaction names the operator, so the page asks for no identifier.
    assert_nil panel.fetch("field")
    assert_nil panel.fetch("identifier_param")
    assert_equal auth_org_sign_in_passkey_options_path(ri: "jp"), panel.fetch("options_url")
    assert_equal auth_org_sign_in_passkey_verification_path(ri: "jp"), panel.fetch("verification_url")
    assert_equal "jp", panel.fetch("region")
    assert_nil inertia_props["secret_link"]
  end

  test "new sends the operator back to the entry when no entra transaction is pending" do
    get new_auth_org_sign_in_passkey_url(ri: "jp")

    assert_response :bad_request
  end

  test "options are refused without a pending entra transaction" do
    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: { identifier: @staff.public_id }

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_nil session[:passkey_challenges]
  end

  test "verification is refused without a pending entra transaction" do
    post auth_org_sign_in_passkey_verification_url(ri: "jp"), params: { challenge_id: "anything" }

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
  end

  test "options bind the challenge to the entra-selected operator and ignore a submitted identifier" do
    other_staff = operators(:two)
    other_staff.update!(status_id: OperatorStatus::ACTIVE)
    complete_org_entra_first_stage!(@staff)

    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: { identifier: other_staff.public_id }

    assert_response :ok
    json = response.parsed_body
    challenge = session[:passkey_challenges].fetch(json.fetch("challenge_id"))

    assert_equal "authentication", challenge["purpose"]
    assert_equal "org:#{@staff.id}", challenge["actor_global_key"]
    assert(
      json.dig("options", "allowCredentials").any? { |c| c["id"] == @staff_passkey.webauthn_id },
      "expected the Entra-selected operator's credential, not the submitted identifier's",
    )
  end

  test "verification returns error if challenge_id blank" do
    complete_org_entra_first_stage!(@staff)

    post auth_org_sign_in_passkey_verification_url(ri: "jp"), params: { challenge_id: "" }

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.webauthn.challenge_id_required")
  end

  test "verification returns error if challenge invalid" do
    complete_org_entra_first_stage!(@staff)

    post auth_org_sign_in_passkey_verification_url(ri: "jp"), params: { challenge_id: "invalid_challenge" }

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.webauthn.challenge_invalid")
  end

  test "verification returns bad request on challenge purpose mismatch" do
    complete_org_entra_first_stage!(@staff)
    challenge_id = issue_challenge!
    mismatch_error = Webauthn::ChallengeStore::ChallengePurposeMismatchError.new("purpose mismatch")

    original_method =
      Auth::Org::Sign::In::Passkey::VerificationsController
        .instance_method(:consume_passkey_challenge_with_actor!)
    Auth::Org::Sign::In::Passkey::VerificationsController
      .define_method(:consume_passkey_challenge_with_actor!) do |*_args, **_kwargs|
      raise mismatch_error
    end

    begin
      post(auth_org_sign_in_passkey_verification_url(ri: "jp"), params: verification_params(challenge_id))
    ensure
      Auth::Org::Sign::In::Passkey::VerificationsController
        .define_method(:consume_passkey_challenge_with_actor!, original_method)
    end

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.webauthn.challenge_invalid")
  end

  test "verification records evidence without establishing an Auth session" do
    complete_org_entra_first_stage!(@staff)
    challenge_id = issue_challenge!

    verified_at = Time.current
    verification_context = Struct.new(:sign_count, :verified_at).new(1, verified_at)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post(
        auth_org_sign_in_passkey_verification_url(ri: "jp", pt: "/settings/passkeys"),
        params: verification_params(challenge_id),
      )
    end

    assert_response :ok
    json = response.parsed_body

    assert_equal "ok", json["status"]
    assert_nil json["access_token"]
    assert_nil json["token_type"]
    assert_nil json["expires_in"]
    assert_equal auth_org_sign_in_check_path(ri: "jp"), json["redirect_url"]

    assert_equal 1, @staff_passkey.reload.sign_count
    assert_not_nil @staff_passkey.reload.last_used_at

    assert_empty OperatorToken.where(staff_id: @staff.id)
  end

  test "the pending transaction is one-shot: a replayed second stage has nothing to continue" do
    complete_org_entra_first_stage!(@staff)
    challenge_id = issue_challenge!
    verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post auth_org_sign_in_passkey_verification_url(ri: "jp"), params: verification_params(challenge_id)
    end

    assert_response :ok

    # The credential ceremony is one-shot; the consumed/cleared transaction has
    # no second-stage challenge to replay.
    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: {}

    assert_response :unprocessable_content
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil session[OrgNormalSignInTransaction::SESSION_KEY]
  end

  test "a credential belonging to another operator is refused after the entra stage" do
    complete_org_entra_first_stage!(@staff)
    challenge_id = issue_challenge!

    other_staff = operators(:two)
    other_staff.update!(status_id: OperatorStatus::ACTIVE)
    other_passkey = OperatorPasskey.create!(
      staff: other_staff,
      webauthn_id: Base64.urlsafe_encode64("other_staff_key_#{SecureRandom.hex(4)}", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "other_staff_key",
      description: "Other Staff Key",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    tokens_before = OperatorToken.where(staff_id: other_staff.id).count

    post auth_org_sign_in_passkey_verification_url(ri: "jp"),
         params: verification_params(challenge_id, credential_id: other_passkey.webauthn_id)

    assert_response :unauthorized
    assert_includes response.body, I18n.t("errors.webauthn.credential_not_found")
    assert_equal tokens_before, OperatorToken.where(staff_id: other_staff.id).count
  end

  test "verification returns unauthorized for credential mismatch" do
    complete_org_entra_first_stage!(@staff)
    challenge_id = issue_challenge!

    post auth_org_sign_in_passkey_verification_url(ri: "jp"),
         params: verification_params(
           challenge_id,
           credential_id: Base64.urlsafe_encode64("unknown_credential", padding: false),
         )

    assert_response :unauthorized
    assert_includes response.body, I18n.t("errors.webauthn.credential_not_found")
  end

  test "verification returns 422 when login result status is unknown" do
    complete_org_entra_first_stage!(@staff)
    challenge_id = issue_challenge!
    verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)

    original_method = Auth::Org::Sign::In::Passkey::VerificationsController.instance_method(:perform_passkey_sign_in)
    Auth::Org::Sign::In::Passkey::VerificationsController.define_method(:perform_passkey_sign_in) do |*_args|
      { status: :unknown_status }
    end

    begin
      Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
        post(auth_org_sign_in_passkey_verification_url(ri: "jp"), params: verification_params(challenge_id))
      end
    ensure
      Auth::Org::Sign::In::Passkey::VerificationsController.define_method(:perform_passkey_sign_in, original_method)
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("errors.login_failed")
  end

  test "verification for staff with mfa enabled succeeds (MFA not enforced for staff)" do
    @staff.update!(mfa_level_enabled: true)
    complete_org_entra_first_stage!(@staff)
    challenge_id = issue_challenge!
    verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post auth_org_sign_in_passkey_verification_url(ri: "jp"), params: verification_params(challenge_id)
    end

    assert_response :ok
    assert_equal "ok", response.parsed_body["status"]
  end

  test "verification hands an at-limit local result to Base for durable resolution" do
    create_rotated_active_staff_session(@staff, rotations: 4)
    complete_org_entra_first_stage!(@staff)
    challenge_id = issue_challenge!
    verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post auth_org_sign_in_passkey_verification_url(ri: "jp"), params: verification_params(challenge_id)
    end

    assert_response :ok
    json = response.parsed_body

    assert_equal "ok", json["status"]
    assert_nil json["access_token"]

    get json.fetch("redirect_url")
    follow_redirect! if response.redirect?
    post auth_org_sign_handoff_path(ri: "jp"), params: { ri: "jp" }
    result_form = response.parsed_body.at_css("form")
    result = result_form.at_css('input[name="result"]')["value"]
    transaction_ref = result_form.at_css('input[name="transaction_ref"]')["value"]
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    post base_org_sign_completion_path,
         params: { result: result, transaction_ref: transaction_ref, ri: "jp" },
         headers: { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_STAFF_URL")}",
                    "Sec-Fetch-Site" => "same-site", }
    follow_redirect! if response.redirect?

    assert_response :success
    assert_equal "base/org/sign/in/limitations/show", inertia_component
    flow = OperatorSignInFlow.where(principal_id: @staff.id).order(created_at: :desc).first

    assert_predicate flow, :sign_in_session_issuance_pending?
    assert_predicate OperatorSessionLimitResolutionTransaction.where(sign_in_flow_id: flow.id).first, :open?
  end

  test "verification returns unauthorized for malformed credential payload" do
    complete_org_entra_first_stage!(@staff)
    challenge_id = issue_challenge!

    post auth_org_sign_in_passkey_verification_url(ri: "jp"), params: {
      challenge_id: challenge_id,
      credential: { invalid: "payload" },
    }

    assert_response :unauthorized
    assert_includes response.body, I18n.t("errors.webauthn.credential_not_found")
  end

  private

  def issue_challenge!
    post(auth_org_sign_in_passkey_options_url(ri: "jp"), params: {})

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

  def create_rotated_active_staff_session(staff, rotations:)
    token = OperatorToken.create!(staff: staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    refresh = token.rotate_refresh_token!

    rotations.times do
      refresh = SignRefreshTokenIssuer.call(refresh_token: refresh)[:refresh_token]
    end
  end
end
