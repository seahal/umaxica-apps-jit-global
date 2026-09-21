# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OrgOperatorLifecycleExecuteTest < ActiveSupport::TestCase
  test "executing an unknown action returns a failure" do
    request = operator_lifecycle_requests(:approved_withdraw_one)
    actor = operators(:two)

    request.update_column(:action, "unknown")

    result = OrgOperatorLifecycleExecute.call(request: request, actor: actor)

    assert_not_predicate result, :success?
    assert_nil result.invitation
  end

  test "suspending the last active operator returns a failure" do
    target = operators(:one)
    request = operator_lifecycle_requests(:approved_withdraw_one)
    actor = operators(:two)

    Operator.where.not(id: target.id).update_all(
      deactivated_at: Time.current,
      withdrawn_at: Time.current,
      discard_at: 1.day.ago,
    )

    result = OrgOperatorLifecycleExecute.call(request: request, actor: actor)

    assert_not_predicate result, :success?
    assert_match(/last active operator/, result.error.downcase)
  end

  test "executing a request by the requester returns a failure" do
    request = operator_lifecycle_requests(:approved_withdraw_one)
    actor = operators(:one)

    result = OrgOperatorLifecycleExecute.call(request: request, actor: actor)

    assert_not_predicate result, :success?
    assert_match(/cannot execute their own/, result.error.downcase)
  end

  test "executing an unapproved request returns a failure" do
    request = operator_lifecycle_requests(:pending_withdraw_two)
    actor = operators(:two)

    result = OrgOperatorLifecycleExecute.call(request: request, actor: actor)

    assert_not_predicate result, :success?
    assert_match(/only approved requests/, result.error.downcase)
  end
end
