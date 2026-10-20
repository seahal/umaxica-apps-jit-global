# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignComUpTelephoneRegistrationFinalizerTest < ActiveSupport::TestCase
  setup do
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  fixtures :visitor_statuses,
           :visitor_visibilities,
           :visitor_mfa_levels,
           :visitor_mfa_statuses,
           :visitor_telephone_statuses

  test "finalizes a pending visitor telephone sign-up" do
    visitor = Visitor.create!(
      public_id: PublicId.generate,
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
      mfa_level_id: VisitorMfaLevel::NOTHING,
      mfa_status_id: VisitorMfaStatus::UNCONFIGURED,
    )
    telephone = VisitorTelephone.create!(
      visitor: visitor,
      raw_number: "+12345678903",
      confirm_policy: "1",
      confirm_using_mfa: "1",
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = "com-telephone-finalization-browser"
    now = VisitorSignUpFlow.database_now
    flow = VisitorSignUpFlow.create!(
      principal_id: visitor.id, status_id: VisitorSignUpFlowStatus::CONTACT_PENDING, step: "contact",
      nonce_digest: VisitorSignUpFlow.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
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

    operation_ref = flow.public_id
    after_receipt = issued.transaction.reload.otp_result_expires_at + 1.second
    VisitorSignUpFlow.stub(:database_now, after_receipt) do
      VisitorTelephoneCeremonyTransaction.stub(:database_now, after_receipt) do
        result = SignComUpTelephoneRegistrationFinalizer.call(
          telephone: telephone,
          actor_context: ActorValuesContext.empty.with(tld: :com, surface: :sign), operation_ref: operation_ref,
          flow: flow, session_nonce: nonce,
        )

        assert_equal visitor, result.visitor
        assert_no_difference "VisitorContactAuditOutbox.count" do
          repeated = SignComUpTelephoneRegistrationFinalizer.call(
            telephone: telephone,
            actor_context: ActorValuesContext.empty.with(tld: :com, surface: :sign), operation_ref: operation_ref,
            flow: flow, session_nonce: nonce,
          )

          assert_equal visitor, repeated.visitor
        end
      end
    end
    activity = VisitorContactAuditOutbox.find_by!(operation_ref: operation_ref)

    assert_equal "finalized", activity.event_name
    assert_equal "telephone", activity.contact_kind
    assert_equal visitor.public_id, activity.owner_ref
    assert_equal telephone.public_id, activity.contact_ref
    assert_nil activity.actor_ref
    assert_nil activity.acknowledged_at
    assert_equal VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP, telephone.reload.visitor_telephone_status_id
    assert_equal retained, telephone.attributes.slice(*retained.keys)
    assert issued.transaction.reload.otp_consumed_at
  end
end
