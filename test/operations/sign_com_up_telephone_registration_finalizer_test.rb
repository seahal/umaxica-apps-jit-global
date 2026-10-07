# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignComUpTelephoneRegistrationFinalizerTest < ActiveSupport::TestCase
  fixtures :visitor_statuses,
           :visitor_visibilities,
           :visitor_mfa_levels,
           :visitor_mfa_statuses,
           :visitor_telephone_statuses

  test "finalizes a pending visitor telephone sign-up" do
    visitor = Visitor.create!(
      public_id: "v_#{SecureRandom.hex(8)}",
      status_id: VisitorStatus::NOTHING,
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
    telephone.store_otp("secret_credential", 789, 5.minutes.from_now.to_i)

    operation_ref = SecureRandom.uuid
    result = SignComUpTelephoneRegistrationFinalizer.call(
      telephone: telephone,
      actor_context: ActorValuesContext.empty.with(tld: :com, surface: :sign), operation_ref: operation_ref,
    )

    assert_equal visitor, result.visitor
    activity = VisitorContactAuditOutbox.find_by!(operation_ref: operation_ref)

    assert_equal "finalized", activity.event_name
    assert_equal "telephone", activity.contact_kind
    assert_equal visitor.public_id, activity.owner_ref
    assert_equal telephone.public_id, activity.contact_ref
    assert_nil activity.actor_ref
    assert_nil activity.acknowledged_at
    assert_equal VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP, telephone.reload.visitor_telephone_status_id
    assert_equal "0", telephone.otp_counter
    assert_equal 0, telephone.otp_attempts_count
    assert_not_predicate telephone, :otp_active?
  end
end
