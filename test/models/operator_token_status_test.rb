# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_token_statuses
# Database name: op_base_org
#
#  id :bigint           not null, primary key
#

require "test_helper"

class OperatorTokenStatusTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 1, OperatorTokenStatus::ACTIVE
    assert_equal 0, OperatorTokenStatus::NOTHING
    assert_equal 102, OperatorTokenStatus::EXPIRED
    assert_equal 103, OperatorTokenStatus::RESTRICTED
    assert_equal 104, OperatorTokenStatus::REVOKED
  end

  test "token status finds its existing operator tokens through the retained staff foreign key" do
    status = OperatorTokenStatus.includes(:staff_tokens).find(OperatorTokenStatus::ACTIVE)

    assert_includes status.staff_tokens.to_a, operator_tokens(:one)
    assert_empty OperatorTokenStatus.includes(:staff_tokens).find(OperatorTokenStatus::REVOKED).staff_tokens.to_a
  end

  test "token status refuses destruction while operator tokens reference it" do
    status = OperatorTokenStatus.find(OperatorTokenStatus::ACTIVE)

    assert_not status.destroy
    assert status.errors.of_kind?(:base, :"restrict_dependent_destroy.has_many")
    assert_predicate status.reload, :persisted?
    assert_predicate operator_tokens(:one).reload, :persisted?
  end

  test "database refuses deletion of an operator token status still in use" do
    status = OperatorTokenStatus.find(OperatorTokenStatus::ACTIVE)

    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        OperatorTokenStatus.transaction(requires_new: true) { status.delete }
      end
    assert_instance_of PG::RestrictViolation, error.cause
    assert_predicate status.reload, :persisted?
    assert_predicate operator_tokens(:one).reload, :persisted?
  end
end
