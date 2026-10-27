# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../../../support/oidc_auth_admission_test_helper"
# require "helpers/global_test_support"

class Auth::App::Sign::In::ChallengesControllerTest < ActionDispatch::IntegrationTest
  include AuthEmailMfaHelper
  include OidcAuthAdmissionTestHelper

  fixtures :clients, :client_statuses, :client_passkey_statuses,
           :client_email_statuses, :client_totp_credential_statuses

  setup do
    @test_started_at = ClientSignInFlow.database_now
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    ClientSignInFlowState.ensure_defaults!
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    @user = Client.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    @email = "challenge_hub_#{SecureRandom.hex(4)}@example.com".freeze
    @email_record = @user.client_emails.create!(address: @email, user_email_status_id: ClientEmailStatus::VERIFIED)
    @email_record.finalize_binding!
    ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      title: "totp",
    )
    bootstrap_auth_sign_in_admission!(surface: "app")
    @primary_sign_in_binding = nil
  end

  test "contradictory MFA GET and HEAD preserve the original app flow and issue no session" do
    establish_contradictory_primary_binding!
    flow = @mfa_flow
    before = flow.attributes
    path = auth_app_sign_in_challenge_path(ri: "jp", fb: @primary_sign_in_binding)

    assert_no_difference -> { ClientToken.count } do
      get path

      assert_response :conflict
      assert_equal "text/plain", response.media_type
      assert_equal "この画面は古くなっています。最初からやり直してください。", response.body
      assert_nil response.headers["Location"]
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_equal before, flow.reload.attributes

      head path

      assert_response :conflict
      assert_empty response.body
      assert_nil response.headers["Location"]
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_equal before, flow.reload.attributes
    end
  end

  test "missing malformed and wrong-surface MFA bindings cannot halt the app flow" do
    establish_contradictory_primary_binding!
    flow = @mfa_flow
    wrong_surface = SignInFlowBindingCodec.encode(flow: flow, surface: "com", phase: "PRIMARY_PENDING")
    before = flow.attributes

    [nil, "", "invalid", wrong_surface].each do |binding|
      assert_no_difference -> { ClientToken.count } do
        delete auth_app_sign_in_challenge_path(ri: "jp", fb: binding)
      end

      assert_response :conflict
      assert_equal "この画面は古くなっています。最初からやり直してください。", response.body
      assert_equal before, flow.reload.attributes
    end
  end

  test "a contradictory app mutation halts once and replay cannot issue a session" do
    establish_contradictory_primary_binding!
    flow = @mfa_flow
    path = auth_app_sign_in_challenge_path(ri: "jp", fb: @primary_sign_in_binding)

    assert_no_difference -> { ClientToken.count } do
      delete path

      assert_response :conflict
      assert_equal "この画面は古くなっています。最初からやり直してください。", response.body
      assert_equal ClientSignInFlowState::HALTED, flow.reload.state_id
      terminal = flow.attributes

      delete path

      assert_response :conflict
      assert_equal terminal, flow.reload.attributes
    end
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "show refuses an MFA request whose binding is ahead of the active phase" do
    establish_contradictory_primary_binding!
    flow = @mfa_flow

    translation_called = false
    original_translate = I18n.method(:t)

    I18n.stub(
      :t,
      ->(key, *args, **options) {
        unless key == "errors.messages.phase_violation_refused"
          next original_translate.call(key, *args, **options)
        end

        translation_called = true

        # The refusal follows the request locale; it no longer forces Japanese (owner, 2026-10-27).
        assert_not options.key?(:locale)
        "この画面は古くなっています。最初からやり直してください。"
      },
    ) do
      get auth_app_sign_in_challenge_path(ri: "jp", fb: @primary_sign_in_binding)
    end

    assert_response :conflict
    assert translation_called
    assert_equal "この画面は古くなっています。最初からやり直してください。", response.body
    assert_equal ClientSignInFlowState::MFA_PENDING, flow.reload.state_id
  end

  test "show refuses a binding whose flow has expired without mutating the flow" do
    establish_contradictory_primary_binding!
    flow = @mfa_flow
    flow.update!(expires_at: flow.issued_at + 1.second)
    expired_binding = SignInFlowBindingCodec.encode(
      flow: flow, surface: "app", phase: "PRIMARY_PENDING",
    )

    travel_to(flow.expires_at + 1.second) do
      get auth_app_sign_in_challenge_path(ri: "jp", fb: expired_binding)

      assert_response :conflict
      assert_equal "この画面は古くなっています。最初からやり直してください。", response.body
      assert_equal ClientSignInFlowState::MFA_PENDING, flow.reload.state_id
    end
  end

  test "a state-changing request bound to this flow but the wrong phase halts the active flow" do
    establish_contradictory_primary_binding!
    flow = @mfa_flow

    delete auth_app_sign_in_challenge_path(ri: "jp", fb: @primary_sign_in_binding)

    assert_response :conflict
    assert_equal "この画面は古くなっています。最初からやり直してください。", response.body
    assert_equal ClientSignInFlowState::HALTED, flow.reload.state_id
  end

  test "show renders for pending_mfa user with MFA enabled" do
    establish_pending_mfa_via_email!

    assert_match(/\A[A-Za-z0-9_-]{21}\z/, session[:pending_mfa].fetch("public_id"))

    follow_redirect!

    assert_response :success
    # Check for translation key in body - translation may be missing or present
    # assert response.body.include?(I18n.t("sign.app.in.mfa.title")) || response.body.include?("translation missing")
    # WU-30: the APP sign-in second factor is a Passkey only; TOTP is never offered.
    assert_equal "auth/app/sign/in/challenges/show", inertia_component
    assert_not_includes inertia_props.fetch("methods").map { |method| method.fetch("key") }, "totp"
  end

  test "show does not display totp method when disabled" do
    @user.client_totp_credentials.delete_all

    establish_pending_mfa_via_email!

    follow_redirect!

    assert_response :success
    assert_not_includes inertia_props.fetch("methods").map { |method| method.fetch("label") },
                        I18n.t("sign.app.in.mfa.methods.totp")
  end

  test "show does not display passkey method when disabled" do
    @user.client_passkeys.delete_all

    establish_pending_mfa_via_email!

    follow_redirect!

    assert_response :success
    assert_not_includes inertia_props.fetch("methods").map { |method| method.fetch("label") },
                        I18n.t("sign.app.in.mfa.methods.passkey")
  end

  # ===================================================================
  # MFA cancellation (DELETE /sign/in/challenge)
  # ===================================================================

  test "destroy ends the pending MFA ceremony and returns to the sign-in entry point" do
    establish_pending_mfa_via_email!
    cycle = ClientSignInFlow.where(principal_id: @user.id).order(:id).last

    assert_predicate cycle, :sign_in_mfa_pending?

    assert_no_difference -> { ClientToken.where(user_id: @user.id).count } do
      delete mfa_challenge_path
    end

    assert_response :see_other
    assert_redirected_to auth_app_sign_in_path(ri: "jp")
    assert_predicate cycle.reload, :sign_in_halted?
    assert_nil session[:pending_mfa]
    assert_nil session[:mfa_user_id]
    assert_nil session[:pending_login_user_id]
    assert_nil session[:app_sign_in_flow_locator]
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY].presence
  end

  test "a cancelled MFA challenge cannot be resumed" do
    establish_pending_mfa_via_email!
    delete mfa_challenge_path

    get new_auth_app_sign_in_challenge_passkey_path(ri: "jp", **mfa_binding_params)

    assert_response :conflict
    assert_equal "この画面は古くなっています。最初からやり直してください。", response.body
  end

  test "A34-2: TOTP is not an APP sign-in method and has no sign-in route" do
    # WU-30: the APP sign-in second factor is a Passkey only.
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}/sign/in/challenge/totp/new", method: :get,
      )
    end
  end

  test "destroy without a pending MFA ceremony changes nothing and returns to sign-in" do
    assert_no_difference -> { ClientToken.count } do
      delete mfa_challenge_path
    end

    # Without an MFA-phase flow the request restarts at the OIDC sign-in page.
    assert_response :see_other
    assert_equal auth_app_sign_in_path(ri: "jp"), URI.parse(response.location).request_uri
  end

  test "the method selection page offers cancellation and no back link" do
    establish_pending_mfa_via_email!
    follow_redirect!

    cancel = inertia_props.fetch("cancel")

    assert_equal I18n.t("actions.cancel"), cancel.fetch("label")
    assert_equal URI.parse(mfa_challenge_path).path, URI.parse(cancel.fetch("action")).path
    assert_equal "delete", cancel.fetch("method")
    assert_not inertia_props.key?("back_link")
  end

  test "with no usable method the page keeps cancellation as the only exit" do
    @user.client_totp_credentials.delete_all
    @user.client_passkeys.delete_all
    establish_pending_mfa_via_email!
    follow_redirect!

    assert_empty inertia_props.fetch("methods")
    assert_predicate inertia_props.fetch("no_methods_notice"), :present?
    assert_not inertia_props.key?("back_link")
    assert_equal "delete", inertia_props.fetch("cancel").fetch("method")
  end

  test "cancelling on the com host leaves the app ceremony untouched" do
    establish_pending_mfa_via_email!

    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    delete auth_com_sign_in_challenge_path(ri: "jp")

    assert_response :see_other

    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    get mfa_challenge_path

    assert_response :success
    assert_predicate ClientSignInFlow.where(principal_id: @user.id).order(:id).last, :sign_in_mfa_pending?
  end

  private

  # An OIDC-parent flow exists only after primary authentication; a PRIMARY binding to that
  # MFA-phase flow is the contradictory observation these cases submit.
  def establish_contradictory_primary_binding!
    sign_in_with_email_to_mfa!(surface: :app, email_record: @email_record, email: @email)
    @mfa_flow = ClientSignInFlow.where(principal_id: @user.id).recent_first.first!
    @primary_sign_in_binding = SignInFlowBindingCodec.encode(flow: @mfa_flow, surface: "app", phase: "PRIMARY_PENDING")
  end

  def establish_pending_mfa_via_email!
    post(
      auth_app_sign_in_email_path(ri: "jp", fb: @primary_sign_in_binding), params: {
        user_email: { address: @email },
        "cf-turnstile-response": "test_token",
      },
    )

    assert_response :found

    delivery =
      ActiveJob::Base.queue_adapter.enqueued_jobs.reverse.find do |entry|
        entry.fetch(:job) == OtpNotifierEmailDeliveryJob
      end
    payload = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last.fetch(:params)
    ceremony = ClientAuthCeremonySession.find(payload.fetch(:auth_ceremony_session_ref))

    assert_equal @email_record.public_id, ceremony.email_otp_context.fetch("contact_ref")
    assert_equal payload.fetch(:auth_email_otp_generation), ceremony.email_otp_context.fetch("generation")
    pass_code = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))

    patch(
      auth_app_sign_in_email_path(ri: "jp", fb: @primary_sign_in_binding), params: {
        user_email: { pass_code: pass_code },
      },
    )

    assert_response :found
    assert_equal auth_app_sign_in_challenge_path, URI.parse(response.location).path
  end

  def mfa_binding_params
    locator = session[:app_sign_in_flow_locator]
    cycle = ClientSignInFlow.find_by(public_id: locator&.[]("public_id"))
    # Only a flow this test created; rows left by non-transactional tests never stand in for it.
    cycle ||= ClientSignInFlow.where(principal_id: @user.id, created_at: @test_started_at..).order(:id).last
    return {} unless cycle

    { fb: SignInFlowBindingCodec.encode(flow: cycle, surface: "app", phase: "MFA_PENDING") }
  end

  def mfa_challenge_path
    auth_app_sign_in_challenge_path(ri: "jp", **mfa_binding_params)
  end
end
