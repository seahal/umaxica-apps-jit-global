# typed: false
# frozen_string_literal: true

require "test_helper"

# The creator serializes candidate creation by destination and leaves binding
# finalization to the later OTP ceremony. A candidate with no digest still
# runs inside a plain transaction, so invalid input cannot leave a pending
# principal behind.
class TelephoneSignupCreatorLockingTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a telephone with no digest to serialise on is refused inside a plain transaction" do
    telephone = ClientTelephone.new(
      raw_number: "", confirm_policy: "1", confirm_using_mfa: "1",
    )

    assert_no_difference -> { ClientTelephone.count } do
      assert_raises(ActiveRecord::RecordInvalid) do
        SignAppUpTelephoneSignupCreator.call(
          telephone: telephone, pending_public_id: nil,
        )
      end
    end
  end

  test "the app creator returns an unfinalized pending candidate" do
    candidate = ClientTelephone.new(
      raw_number: "+1234567650", confirm_policy: "1", confirm_using_mfa: "1",
    )
    candidate.validate

    result =
      SignAppUpTelephoneSignupCreator.call(
        telephone: candidate, pending_public_id: nil,
      )

    assert_equal :created, result.status
    assert_predicate result.telephone, :present?
    assert_nil result.telephone.binding_finalized_at
    assert_equal result.telephone.public_id, result.session_payload.fetch(:public_id)
  end

  test "the corporate creator returns an unfinalized pending candidate" do
    candidate = VisitorTelephone.new(
      raw_number: "+819012377650", confirm_policy: true, confirm_using_mfa: true,
    )
    candidate.validate

    result = SignComUpTelephoneSignupCreator.call(telephone: candidate, pending_public_id: nil)

    assert_equal :created, result.status
    assert_nil result.telephone.binding_finalized_at
    assert_equal result.telephone.public_id, result.session_payload.fetch(:public_id)
  end
end
