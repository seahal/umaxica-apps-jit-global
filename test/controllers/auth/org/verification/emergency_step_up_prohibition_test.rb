# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

# Step-Up is unavailable to a Restricted Mode session.
#
# This is not "step-up has not happened yet". The authentication context is not
# eligible to perform step-up-protected operations at all, so possessing a
# perfectly valid step-up passkey changes nothing: the ceremony entry is
# refused, a direct POST is refused, and no path can leave the session holding
# usable step-up freshness.
class Auth::Org::Verification::EmergencyStepUpProhibitionTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_tokens

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    @staff = operators(:one)
    @token = operator_tokens(:one)
    @passkey = OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "org_emergency_step_up_#{SecureRandom.hex(8)}",
      external_id: SecureRandom.uuid,
      public_key: "org-emergency-public-key",
      sign_count: 0,
      description: "Org step-up passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
  end

  def headers_for(context)
    @token.update!(authentication_context: context)
    @token.reload

    as_staff_headers(@staff, host: @host, session_public_id: @token.public_id)
  end

  test "an emergency session is refused at the step-up ceremony entry" do
    return_to = auth_org_settings_passkeys_path(ri: "jp")

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      get auth_org_verification_url(
        scope: "settings_passkey",
        pt: signed_step_up_pt(return_to),
        ri: "jp",
        step_up_ceremony_grant: signed_step_up_grant_for(
          actor: @staff, token: @token, scope: "settings_passkey", return_to: return_to, surface: "org",
        ),
      ), headers: headers_for("emergency")
    end

    assert_response :forbidden
    assert_includes response.body, I18n.t("auth.step_up.emergency_unavailable")
  end

  test "an emergency session is refused when it reaches the passkey ceremony page directly" do
    StepUpAvailableMethods.stub(:call, [:passkey]) do
      get new_auth_org_verification_passkey_url(ri: "jp"), headers: headers_for("emergency")
    end

    assert_response :forbidden
    assert_includes response.body, I18n.t("auth.step_up.emergency_unavailable")
  end

  test "a direct step-up POST from an emergency session creates no freshness" do
    emergency_headers = headers_for("emergency")

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)
      Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
        post auth_org_verification_passkey_url(ri: "jp"),
             params: {
               verification: {
                 challenge_id: "anything",
                 credential_json: { id: @passkey.webauthn_id }.to_json,
               },
             },
             headers: emergency_headers
      end
    end

    assert_response :forbidden

    @token.reload

    assert_nil @token.last_step_up_at
    assert_nil @token.last_step_up_scope
    assert_equal "emergency", @token.authentication_context
  end

  # The resolver is the single authority every policy and controller consults,
  # so a session that somehow held freshness columns still cannot satisfy a
  # requirement while its context is Emergency.
  test "recorded freshness cannot satisfy a requirement in an emergency context" do
    now = Time.current
    @token.update!(
      last_step_up_at: now,
      last_step_up_scope: "settings_passkey",
      last_step_up_method: "passkey",
      last_step_up_aal: "aal1",
      last_step_up_purpose: "step_up",
      last_step_up_audience: "org",
      last_step_up_session_public_id: @token.public_id,
    )
    requirement = StepUpRequirement.new(
      scope: "settings_passkey",
      required_aal: "aal1",
      allowed_methods: [:passkey],
      session_binding: @token.public_id,
      token_binding: @token.public_id,
      ttl: VerificationBase::STEP_UP_TTL,
      purpose: :step_up,
      audience: "org",
      require_session_binding: true,
    )

    @token.update!(authentication_context: nil)

    assert_predicate StepUpResolver.call(token: @token.reload, requirement: requirement), :satisfied?,
                     "the fixture must satisfy the requirement in a normal context, or the next " \
                     "assertion proves nothing"

    @token.update!(authentication_context: "emergency")

    assert_not_predicate StepUpResolver.call(token: @token.reload, requirement: requirement), :satisfied?
  end

  test "the freshness committer refuses to write onto an emergency session" do
    @token.update!(authentication_context: "emergency")

    error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityStepUpCeremonyFreshnessCommitter.call!(
          result_token: "unused",
          token: @token.reload,
          expected_scope: "settings_passkey",
          expected_aal: "aal1",
          expected_method: "passkey",
          audience: "org",
        )
      end

    assert_match(/authentication context/, error.message)
    assert_nil @token.reload.last_step_up_at
  end

  test "normal step-up behaviour is unchanged" do
    return_to = auth_org_settings_passkeys_path(ri: "jp")

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      get auth_org_verification_url(
        scope: "settings_passkey",
        pt: signed_step_up_pt(return_to),
        ri: "jp",
        step_up_ceremony_grant: signed_step_up_grant_for(
          actor: @staff, token: @token, scope: "settings_passkey", return_to: return_to, surface: "org",
        ),
      ), headers: headers_for(nil)
    end

    assert_response :success
  end

  private

  def signed_step_up_pt(return_to)
    issuer = Class.new do
      include ::RedirectsSignedTargetSupport

      def issue(return_to:, surface:, session_nonce:)
        path = signed_target_internal_path(return_to)
        claims = signed_target_claims(flow: "step_up.bootstrap", surface: surface, session_nonce: session_nonce)
        issue_signed_target_token(
          payload: claims.merge("pt" => path),
          purpose: VerificationBase::STEP_UP_PATH_TARGET_TOKEN_PURPOSE,
          salt: VerificationBase::STEP_UP_PATH_TARGET_TOKEN_SALT,
          expires_in: VerificationBase::STEP_UP_TTL,
        )
      end
    end.new

    issuer.issue(return_to: return_to, surface: "org", session_nonce: @token.public_id)
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
end
