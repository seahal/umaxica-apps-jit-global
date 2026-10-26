# typed: false
# frozen_string_literal: true

require "test_helper"

# The creator serializes candidate creation by destination and leaves binding
# finalization to the later OTP ceremony. A candidate with no digest still
# runs inside a plain transaction, so invalid input cannot leave a pending
# principal behind.
class TelephoneSignupCreatorLockingTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "signup creation refuses persisted Telephone candidates without transferring their owner" do
    [[Client, ClientTelephone, :user, :user_id], [Visitor, VisitorTelephone, :visitor, :visitor_id]].each do |
      owner_model, telephone_model, association, owner_key|
      owner = owner_model.create!(security_mode_id: SecurityModeTestDefault.id_for(owner_model))
      telephone = telephone_model.create!(
        association => owner, :raw_number => "+12025550161", :confirm_policy => true,
      )
      original_status =
        (telephone_model == ClientTelephone) ? telephone.user_telephone_status_id :
                               telephone.visitor_telephone_status_id

      assert_no_difference [-> { owner_model.count }, -> { telephone_model.count }] do
        assert_raises(ArgumentError) { TelephoneSignUpCandidateCreator.call(telephone: telephone) }
      end

      assert_equal owner.id, telephone.reload[owner_key]
      assert_equal original_status, (telephone_model == ClientTelephone) ? telephone.user_telephone_status_id :
                                   telephone.visitor_telephone_status_id
    end
  end

  test "signup creation refuses new Telephone candidates with persisted or unsaved owners" do
    [[Client, ClientTelephone, :user], [Visitor, VisitorTelephone, :visitor]].each do |
      owner_model, telephone_model, association|
      [owner_model.create!(security_mode_id: SecurityModeTestDefault.id_for(owner_model)),
       owner_model.new(security_mode_id: SecurityModeTestDefault.id_for(owner_model)),].each do |owner|
        telephone = telephone_model.new(
          association => owner, :raw_number => "+12025550162", :confirm_policy => true,
        )

        assert_no_difference [-> { owner_model.count }, -> { telephone_model.count }] do
          assert_raises(ArgumentError) { TelephoneSignUpCandidateCreator.call(telephone: telephone) }
        end

        assert_predicate telephone, :new_record?
        assert_same owner, (telephone_model == ClientTelephone) ? telephone.user : telephone.visitor
      end
    end
  end

  test "a telephone with no digest to serialise on is refused inside a plain transaction" do
    telephone = ClientTelephone.new(
      raw_number: "", confirm_policy: "1", confirm_using_mfa: "1",
    )

    assert_no_difference -> { ClientTelephone.count } do
      assert_raises(ActiveRecord::RecordInvalid) do
        TelephoneSignUpCandidateCreator.call(telephone: telephone)
      end
    end
  end

  test "the app creator returns an unfinalized pending candidate" do
    candidate = ClientTelephone.new(
      raw_number: "+1234567650", confirm_policy: "1", confirm_using_mfa: "1",
    )
    candidate.validate

    result = TelephoneSignUpCandidateCreator.call(telephone: candidate)

    assert_equal :created, result.status
    assert_predicate result.telephone, :present?
    assert_nil result.telephone.binding_finalized_at
    assert_equal result.telephone.public_id, result.session_payload.fetch(:public_id)
    assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, result.telephone.user.status_id
    assert_equal ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, result.telephone.user_telephone_status_id
    assert_instance_of TrueClass, result.session_payload.fetch(:confirm_policy)
    assert_instance_of TrueClass, result.session_payload.fetch(:confirm_using_mfa)
    assert_not result.session_payload.key?(:expires_at), "Only the subsequent ceremony owns expiry"
  end

  test "the corporate creator returns an unfinalized pending candidate" do
    candidate = VisitorTelephone.new(
      raw_number: "+819012377650", confirm_policy: true, confirm_using_mfa: true,
    )
    candidate.validate

    result = TelephoneSignUpCandidateCreator.call(telephone: candidate)

    assert_equal :created, result.status
    assert_nil result.telephone.binding_finalized_at
    assert_equal result.telephone.public_id, result.session_payload.fetch(:public_id)
    assert_equal VisitorStatus::UNVERIFIED_WITH_SIGN_UP, result.telephone.visitor.status_id
    assert_equal VisitorVisibility::VISITOR, result.telephone.visitor.visibility_id
    assert_equal VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, result.telephone.visitor_telephone_status_id
    assert_instance_of TrueClass, result.session_payload.fetch(:confirm_policy)
    assert_instance_of TrueClass, result.session_payload.fetch(:confirm_using_mfa)
    assert_not result.session_payload.key?(:expires_at), "Only the subsequent ceremony owns expiry"
  end
end
