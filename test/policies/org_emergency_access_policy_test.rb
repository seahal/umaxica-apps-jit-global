# typed: false
# frozen_string_literal: true

require "test_helper"

# Emergency eligibility is one decision in one place. It is open to every
# operator who may sign in at all today; what this file protects is that it stays
# a single decision, so restricting it later cannot miss a caller.
class OrgEmergencyAccessPolicyTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses

  setup do
    @operator = operators(:one)
    @operator.update!(status_id: OperatorStatus::ACTIVE)
  end

  test "an operator who may sign in is eligible" do
    assert OrgEmergencyAccessPolicy.eligible?(@operator)
  end

  test "an operator who may not sign in is not eligible" do
    @operator.update!(withdrawn_at: Time.current)

    assert_not OrgEmergencyAccessPolicy.eligible?(@operator)
  end

  test "an administratively locked operator is not eligible" do
    locked = Object.new
    locked.define_singleton_method(:is_a?) { |klass| klass == ::Operator }
    locked.define_singleton_method(:login_allowed?) { true }
    locked.define_singleton_method(:admin_locked?) { true }

    assert_not OrgEmergencyAccessPolicy.eligible?(locked)
  end

  test "a non-operator is never eligible" do
    assert_not OrgEmergencyAccessPolicy.eligible?(nil)
    assert_not OrgEmergencyAccessPolicy.eligible?(Object.new)
  end
end
