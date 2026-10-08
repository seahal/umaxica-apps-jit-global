# typed: false
# frozen_string_literal: true

require "test_helper"

# Both account-recovery entry points shipped with structurally broken ERB and
# returned 500, because no request test exercised either route. Account recovery
# is the fallback path when a user is locked out, so a 500 here pushes people to
# support-channel identity proofing instead.
#
# Full template coverage lives in test/unit/views/template_compilation_test.rb,
# which compiles all templates. These tests pin the routes themselves.
class IdentityRecoveryEntrypointRenderTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "com recovery session entry point renders" do
    get "http://base.com.localhost/identity/recovery/session/new?ri=jp"

    assert_response :success
    assert_match "Account recovery", response.body
  end

  test "app recovery session entry point renders" do
    get "http://base.app.localhost/identity/recovery/session/new?ri=jp"

    assert_response :success
    assert_match "Account recovery", response.body
  end

  test "app recovery status page redirects to the entry point without a ceremony" do
    # Base::App::Identity::RecoveriesController#show is :open but requires a
    # recovery ceremony cookie. Without one it must redirect, not error.
    get "http://base.app.localhost/identity/recovery?ri=jp"

    assert_response :see_other
    assert_match "/identity/recovery/session/new", response.location
  end

  test "com recovery status page redirects to the entry point without a ceremony" do
    get "http://base.com.localhost/identity/recovery?ri=jp"

    assert_response :see_other
    assert_match "/identity/recovery/session/new", response.location
  end

  test "app recovery keeps an unknown email enumeration-resistant and rejects its OTP" do
    post "http://base.app.localhost/identity/recovery/session?ri=jp",
         params: { recovery_reentry: { address: "unknown-recovery@example.test" } }

    assert_response :success
    assert_match "Account recovery", response.body

    post "http://base.app.localhost/identity/recovery/session?ri=jp", params: { pass_code: "000000" }

    assert_response :unprocessable_content
    assert_match "Account recovery", response.body
  end

  test "com recovery keeps an unknown email enumeration-resistant and rejects its OTP" do
    post "http://base.com.localhost/identity/recovery/session?ri=jp",
         params: { recovery_reentry: { address: "unknown-recovery@example.test" } }

    assert_response :success
    assert_match "Account recovery", response.body

    post "http://base.com.localhost/identity/recovery/session?ri=jp", params: { pass_code: "000000" }

    assert_response :unprocessable_content
    assert_match "Account recovery", response.body
  end

  test "app recovery start keeps registered and unknown email responses equivalent across sessions" do
    client = create_client
    email = create_verified_client_email(client, address: "recovery-equivalence-client@example.test")
    activate_recovery_case(AppEnforcementCase, client)
    registered_session = open_session
    unknown_session = open_session

    assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
      registered_session.post(
        "http://base.app.localhost/identity/recovery/session?ri=jp",
        params: { recovery_reentry: { address: email.address } },
      )
      unknown_session.post(
        "http://base.app.localhost/identity/recovery/session?ri=jp",
        params: { recovery_reentry: { address: "recovery-equivalence-unknown@example.test" } },
      )
    end

    assert_equal registered_session.response.status, unknown_session.response.status
    assert_equal registered_session.response.headers["Content-Type"],
                 unknown_session.response.headers["Content-Type"]
    assert_equal registered_session.response.headers["Cache-Control"],
                 unknown_session.response.headers["Cache-Control"]
    assert_match "Account recovery", registered_session.response.body
    assert_match "Account recovery", unknown_session.response.body
    assert_match "Verification code", registered_session.response.body
    assert_match "Verification code", unknown_session.response.body
  end

  test "com recovery start keeps registered and unknown email responses equivalent across sessions" do
    visitor = create_visitor
    email = create_verified_visitor_email(visitor, address: "recovery-equivalence-visitor@example.test")
    activate_recovery_case(ComEnforcementCase, visitor)
    registered_session = open_session
    unknown_session = open_session

    assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
      registered_session.post(
        "http://base.com.localhost/identity/recovery/session?ri=jp",
        params: { recovery_reentry: { address: email.address } },
      )
      unknown_session.post(
        "http://base.com.localhost/identity/recovery/session?ri=jp",
        params: { recovery_reentry: { address: "recovery-equivalence-unknown@example.test" } },
      )
    end

    assert_equal registered_session.response.status, unknown_session.response.status
    assert_equal registered_session.response.headers["Content-Type"],
                 unknown_session.response.headers["Content-Type"]
    assert_equal registered_session.response.headers["Cache-Control"],
                 unknown_session.response.headers["Cache-Control"]
    assert_match "Account recovery", registered_session.response.body
    assert_match "Account recovery", unknown_session.response.body
    assert_match "Verification code", registered_session.response.body
    assert_match "Verification code", unknown_session.response.body
  end

  test "app recovery issues a ceremony only after a verified email OTP for an active security lock" do
    client = create_client
    email = create_verified_client_email(client, address: "recovery-client@example.test")
    activate_recovery_case(AppEnforcementCase, client)

    original_proof = email.attributes.slice("otp_private_key", "otp_counter", "otp_expires_at")

    assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
      post "http://base.app.localhost/identity/recovery/session?ri=jp",
           params: { recovery_reentry: { address: email.address } }
    end

    assert_response :success
    proof_unchanged = original_proof == email.reload.attributes.slice(*original_proof.keys)

    assert proof_unchanged
    payload = ActiveJob::Arguments.deserialize(enqueued_jobs.last.fetch(:args)).last.fetch(:params)
    pass_code = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: payload.fetch(:email_ceremony_transaction_ref),
    )

    assert_equal "recovery", transaction.operation

    assert_difference -> { ClientEnforcementRecoveryCeremony.count }, 1 do
      post "http://base.app.localhost/identity/recovery/session?ri=jp", params: { pass_code: pass_code }
    end

    assert_response :see_other
    assert_redirected_to base_app_identity_recovery_path(ri: "jp")
    assert transaction.reload.otp_consumed_at
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
  end

  private

  def activate_recovery_case(case_class, subject)
    enforcement_case = case_class.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: subject.public_id, applied_by_operator_public_id: "recovery-test-operator",
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: enforcement_case,
      actor_operator_public_id: enforcement_case.applied_by_operator_public_id,
    )
  end

  def create_client
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    Client.create!(
      status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING, mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
  end

  def create_verified_client_email(client, address:)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientEmail.create!(
      user: client, address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
  end

  def create_visitor
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
  end

  def create_verified_visitor_email(visitor, address:)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorEmail.create!(
      visitor: visitor, address: address, confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
  end
end
