# typed: false
# frozen_string_literal: true

require_relative "coverage_threshold_services_test"

class CoverageThresholdStateMachineEdgesTest < ActiveSupport::TestCase
  def ticket(status = "STARTED")
    CoverageThresholdServicesTest::MachineTicket.new(status)
  end
  test "state machine rejects unknown events and malformed payloads" do
    t = ticket

    assert_equal :invalid_transition, SignUpStateMachine.call(ticket: t, event: :unknown, actor_context: nil).status
    machine = SignUpStateMachine.new(ticket: t, event: :start, actor_context: nil, payload: Object.new)

    assert_equal({}, machine.payload)
    t.define_singleton_method(:persisted?) { true }
    t.define_singleton_method(:with_cycle_lock) { |&block| block.call }
    t.define_singleton_method(:reload) { self }

    assert_equal :ok, machine.call.status
  end
end
