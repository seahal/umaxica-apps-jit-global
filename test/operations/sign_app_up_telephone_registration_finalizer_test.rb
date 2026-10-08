# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignAppUpTelephoneRegistrationFinalizerTest < ActiveSupport::TestCase
  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  fixtures :client_statuses,
           :client_visibilities,
           :client_mfa_levels,
           :client_mfa_statuses,
           :client_telephone_statuses,
           :client_passkey_statuses,
           :client_chronicle_events,
           :client_chronicle_levels

  test "finalizes a pending telephone sign-up after passkey setup" do
    user = Client.create!(
      public_id: "c_#{SecureRandom.hex(8)}",
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
      visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
    telephone = ClientTelephone.create!(
      user: user,
      raw_number: "+12345678901",
      confirm_policy: "1",
      confirm_using_mfa: "1",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = "app-telephone-finalization-browser"
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      principal_id: user.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING, step: "contact",
      nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
      entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: telephone.id,
    )
    issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
    verified = TelephoneSignUpOtpVerificationCommitter.call(
      flow: flow, telephone: telephone, session_nonce: nonce, code: issued.code,
    )

    assert_predicate verified, :success?
    flow.verify_sign_up_contact!
    flow.advance_sign_up_to_guardrail!
    flow.advance_sign_up_to_checkpoint!
    flow.update!(completed_requirements: { "otp" => { "cleared" => true } })
    telephone.update!(otp_attempts_count: 2)
    retained = telephone.reload.attributes.slice("otp_attempts_count", "locked_at", "otp_last_sent_at")
    ClientPasskey.create!(
      user: user,
      webauthn_id: SecureRandom.uuid,
      public_key: "public-key",
      description: "Primary passkey",
      sign_count: 0,
    )

    operation_ref = flow.public_id
    context = ActorValuesContext.empty.with(tld: :app, surface: :sign)
    after_receipt = issued.transaction.reload.otp_result_expires_at + 1.second
    ClientSignUpFlow.stub(:database_now, after_receipt) do
      ClientTelephoneCeremonyTransaction.stub(:database_now, after_receipt) do
        assert_difference "ClientContactAuditOutbox.count", 1 do
          result = SignAppUpTelephoneRegistrationFinalizer.call(
            telephone: telephone, actor_context: context, operation_ref: operation_ref,
            flow: flow, session_nonce: nonce,
          )

          assert_equal user, result.user
          repeated = SignAppUpTelephoneRegistrationFinalizer.call(
            telephone: telephone, actor_context: context, operation_ref: operation_ref,
            flow: flow, session_nonce: nonce,
          )

          assert_equal user, repeated.user
        end
      end
    end

    activity = ClientContactAuditOutbox.find_by!(operation_ref: operation_ref)

    assert_equal "finalized", activity.event_name
    assert_equal "telephone", activity.contact_kind
    assert_equal user.public_id, activity.owner_ref
    assert_equal telephone.public_id, activity.contact_ref
    assert_nil activity.actor_ref
    assert_nil activity.acknowledged_at
    assert_equal 1, ClientContactAuditOutbox.where(operation_ref: operation_ref).count
    assert_equal ClientTelephoneStatus::VERIFIED_WITH_SIGN_UP, telephone.reload.user_telephone_status_id
    assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, user.reload.status_id
    assert_equal retained, telephone.attributes.slice(*retained.keys)
    assert issued.transaction.reload.otp_consumed_at
  end

  test "raises when the required passkey is missing and rolls back the registration" do
    user = Client.create!(
      public_id: "c_#{SecureRandom.hex(8)}",
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
      visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
    telephone = ClientTelephone.create!(
      user: user,
      raw_number: "+12345678902",
      confirm_policy: "1",
      confirm_using_mfa: "1",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = "app-missing-passkey-browser"
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      principal_id: user.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING, step: "contact",
      nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
      entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: telephone.id,
    )
    issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
    verified = TelephoneSignUpOtpVerificationCommitter.call(
      flow: flow, telephone: telephone, session_nonce: nonce, code: issued.code,
    )

    assert_predicate verified, :success?
    flow.verify_sign_up_contact!
    flow.advance_sign_up_to_guardrail!
    flow.advance_sign_up_to_checkpoint!
    flow.update!(completed_requirements: { "otp" => { "cleared" => true } })
    retained = telephone.reload.attributes.slice("otp_attempts_count", "locked_at", "otp_last_sent_at")

    assert_no_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::SIGNED_UP_WITH_TELEPHONE).count } do
      assert_raises(SignAppUpTelephoneRegistrationFinalizer::PasskeyMissingError) do
        SignAppUpTelephoneRegistrationFinalizer.call(
          telephone: telephone,
          actor_context: ActorValuesContext.empty.with(tld: :app, surface: :sign), operation_ref: flow.public_id,
          flow: flow, session_nonce: nonce,
        )
      end
    end

    assert_equal ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, telephone.reload.user_telephone_status_id
    assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, user.reload.status_id
    assert_equal retained, telephone.attributes.slice(*retained.keys)
    assert issued.transaction.reload.otp_consumed_at
  end
end
