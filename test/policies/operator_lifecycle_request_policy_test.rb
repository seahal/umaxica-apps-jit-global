# typed: false
# frozen_string_literal: true

require "test_helper"

# The lifecycle policy is closed until operator-to-operator capabilities are specified; an Operator
# acting on another Operator's request, the case the previous type-only rule allowed, is denied.
class OperatorLifecycleRequestPolicyTest < ActiveSupport::TestCase
  test "every rule denies an operator reviewing another operator's pending request" do
    record = OperatorLifecycleRequest.new(
      status: OperatorLifecycleRequest::STATUS_PENDING,
      requested_by_operator_id: 999,
    )
    policy = OperatorLifecycleRequestPolicy.new(record, user: Operator.new(id: 1))

    %i(index? show? create? approve? reject? execute?).each do |rule|
      assert_not policy.public_send(rule), "expected #{rule} to deny"
    end
  end

  test "every rule denies an operator even on an approved request they did not file" do
    record = OperatorLifecycleRequest.new(
      status: OperatorLifecycleRequest::STATUS_APPROVED,
      requested_by_operator_id: 999,
    )
    policy = OperatorLifecycleRequestPolicy.new(record, user: Operator.new(id: 1))

    assert_not policy.execute?
  end
end
