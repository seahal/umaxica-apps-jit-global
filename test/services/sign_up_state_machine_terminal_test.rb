# typed: false
# frozen_string_literal: true

require "test_helper"

# A sign-up ticket that does not answer for its own terminal state is judged
# from the status names instead, so a ticket type without the predicate is never
# treated as still in progress once it has completed, failed, expired or been
# cancelled.
class SignUpStateMachineTerminalTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class PlainTicket
    def initialize(status_name) = @status_name = status_name

    def status_id = @status_name

    def status_id_for(name) = name
  end

  def machine_for(ticket)
    machine = SignUpStateMachine.allocate
    machine.define_singleton_method(:ticket) { ticket }
    machine
  end

  test "a ticket without a terminal predicate is judged from its status name" do
    %w(COMPLETED FAILED EXPIRED CANCELLED).each do |status_name|
      assert machine_for(PlainTicket.new(status_name)).send(:terminal?),
             "expected #{status_name} to be a terminal status"
    end

    assert_not machine_for(PlainTicket.new("STARTED")).send(:terminal?)
  end

  test "a ticket that answers for itself is trusted over the status names" do
    ticket = PlainTicket.new("STARTED")
    ticket.define_singleton_method(:sign_up_terminal?) { true }

    assert machine_for(ticket).send(:terminal?)
  end
end
