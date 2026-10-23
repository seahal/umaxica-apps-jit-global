# typed: false
# frozen_string_literal: true

require "test_helper"

# D-134: the database makes the ORG halt audit exactly-once per transaction and halt generation.
class OperatorChronicleSignFlowHaltedTest < ActiveSupport::TestCase
  setup do
    @operator = operators(:one)
  end

  test "a second SIGN_FLOW_HALTED row for the same transaction and generation is rejected" do
    halt!(transaction: "txn-a", generation: "100")

    assert_raises(ActiveRecord::RecordNotUnique) { halt!(transaction: "txn-a", generation: "100") }
  end

  test "another generation or another transaction is a separate halt" do
    halt!(transaction: "txn-b", generation: "100")

    assert_nothing_raised do
      halt!(transaction: "txn-b", generation: "101")
      halt!(transaction: "txn-c", generation: "100")
    end
  end

  test "a SIGN_FLOW_HALTED row without its correlation keys is rejected" do
    assert_raises(ActiveRecord::StatementInvalid) do
      OperatorChronicle.create!(base_attributes.merge(context: { reason_code: "phase_violation" }))
    end
  end

  test "other events are unaffected by the halt index and check" do
    assert_nothing_raised do
      2.times do
        OperatorChronicle.create!(base_attributes.merge(event_id: OperatorChronicleEvent::LOGGED_IN, context: {}))
      end
    end
  end

  private

  def halt!(transaction:, generation:)
    OperatorChronicle.create!(
      base_attributes.merge(context: { transaction_public_id: transaction, halt_generation: generation }),
    )
  end

  def base_attributes
    { actor: @operator,
      subject_type: "OrgNormalSignInTransaction",
      subject_id: @operator.id,
      event_id: OperatorChronicleEvent::SIGN_FLOW_HALTED,
      occurred_at: Time.current, }
  end
end
