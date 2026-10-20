# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_email_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class OperatorEmailStatusTest < ActiveSupport::TestCase
  fixtures :operator_email_statuses

  test "valid status with id" do
    status = OperatorEmailStatus.find(OperatorEmailStatus::UNVERIFIED)

    assert_predicate status, :valid?
  end

  test "has many operator_emails" do
    assert OperatorEmailStatus.reflect_on_association(:operator_emails)
  end

  test "status constants are defined" do
    assert_equal 6, OperatorEmailStatus::UNVERIFIED
    assert_equal 7, OperatorEmailStatus::VERIFIED
  end

  test "additional status constants are defined" do
    assert_equal 1, OperatorEmailStatus::ACTIVE
    assert_equal 2, OperatorEmailStatus::DELETED
  end

  test "restrict_with_error prevents deletion when emails exist" do
    status = OperatorEmailStatus.find(OperatorEmailStatus::VERIFIED)
    # Create a staff identity email with this status
    staff = Operator.create!
    OperatorEmail.create!(
      address: "staff@example.com",
      staff_id: staff.id,
      staff_email_status_id: status.id,
      public_id: PublicId.generate,
    )

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      status.destroy!
    end
  end
end
