# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_telephone_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class OperatorTelephoneStatusTest < ActiveSupport::TestCase
  fixtures :operator_telephone_statuses, :operators, :operator_statuses

  test "valid status with id" do
    status = OperatorTelephoneStatus.find(OperatorTelephoneStatus::UNVERIFIED)

    assert_predicate status, :valid?
  end

  test "has many staff_telephones" do
    assert OperatorTelephoneStatus.reflect_on_association(:staff_telephones)
  end

  test "status constants are defined" do
    assert_equal 6, OperatorTelephoneStatus::UNVERIFIED
    assert_equal 7, OperatorTelephoneStatus::VERIFIED
  end

  test "additional status constants are defined" do
    assert_equal 1, OperatorTelephoneStatus::ACTIVE
    assert_equal 2, OperatorTelephoneStatus::DELETED
  end

  test "restrict_with_error prevents deletion when telephones exist" do
    status = OperatorTelephoneStatus.find(OperatorTelephoneStatus::VERIFIED)
    # Create a staff identity telephone with this status
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    OperatorTelephone.create!(
      number: "+81901234567",
      staff_id: staff.id,
      staff_telephone_status_id: status.id,
    )

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      status.destroy!
    end
  end
end
