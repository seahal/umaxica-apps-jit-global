# typed: false
# frozen_string_literal: true

require "test_helper"

class WithdrawalFlowTest < ActiveSupport::TestCase
  CYCLE_CLASSES = [
    ClientWithdrawalFlow,
    VisitorWithdrawalFlow,
  ].freeze

  test "withdrawal status reference tables use the agreed fixed ids" do
    CYCLE_CLASSES.each do |cycle_class|
      assert_equal 0, cycle_class::STATUS_MODEL::NOTHING
      assert_equal 10, cycle_class::STATUS_MODEL::REQUESTED
      assert_equal 20, cycle_class::STATUS_MODEL::CLOSING
      assert_equal 30, cycle_class::STATUS_MODEL::DISCARDED
      assert_equal 40, cycle_class::STATUS_MODEL::RECOVERED
      assert_equal 100, cycle_class::STATUS_MODEL::TERMINATED
      assert_equal 900, cycle_class::STATUS_MODEL::FAILED
      assert_equal [0, 10, 20, 30, 40, 100, 900], cycle_class::STATUS_MODEL::DEFAULTS
    end
  end

  test "withdrawal cycles default to requested and record the initial event" do
    cycle = ClientWithdrawalFlow.create!(client: create_client)

    assert_predicate cycle, :withdrawal_requested?
    assert_equal ClientWithdrawalFlowStatus::REQUESTED, cycle.status_id

    event = ClientWithdrawalFlowEvent.find_by!(client_withdrawal_flow_id: cycle.id)

    assert_equal ClientWithdrawalFlowStatus::NOTHING, event.from_status_id
    assert_equal ClientWithdrawalFlowStatus::REQUESTED, event.to_status_id
    assert_equal cycle.client_id, event.client_id
    assert_in_delta Float(cycle.began_at), Float(event.occurred_at), 0.001
  end

  test "withdrawal cycle methods progress through closing and discarded states with events" do
    now = Time.zone.local(2026, 5, 19, 12, 0, 0)

    cycle = nil
    travel_to now do
      cycle = ClientWithdrawalFlow.create!(client: create_client)

      assert_predicate cycle, :withdrawal_requested?
      cycle.confirm_withdrawal!(token_public_id: "token-one", reason: "confirmed")

      assert_predicate cycle, :withdrawal_closing?
      cycle.discard_withdrawal!(token_public_id: "token-one", reason: "finalized")
    end

    cycle.reload

    assert_predicate cycle, :withdrawal_discarded?

    events = ClientWithdrawalFlowEvent.where(client_withdrawal_flow_id: cycle.id).order(:occurred_at, :id).to_a

    assert_equal 3, events.size
    assert_equal ClientWithdrawalFlowStatus::CLOSING, events.second.to_status_id
    assert_equal "confirmed", events.second.reason
    assert_equal "token-one", events.second.token_public_id
    assert_equal ClientWithdrawalFlowStatus::DISCARDED, events.third.to_status_id
  end

  test "withdrawal failure is allowed before discard completion" do
    cycle = ClientWithdrawalFlow.create!(client: create_client)

    cycle.fail_withdrawal!(reason: "manual-stop")

    assert_predicate cycle, :withdrawal_failed?
    assert_predicate ClientWithdrawalFlowEvent.where(client_withdrawal_flow_id: cycle.id).last, :present?
  end

  test "withdrawal recovery completes the cycle and records completion time" do
    now = Time.zone.local(2026, 5, 19, 12, 0, 0)
    cycle = ClientWithdrawalFlow.create!(client: create_client)
    cycle.confirm_withdrawal!
    cycle.discard_withdrawal!

    travel_to now do
      cycle.recover_withdrawal!(reason: "recovered")
    end

    cycle.reload

    assert_predicate cycle, :withdrawal_recovered?
    assert_equal now, cycle.completed_at

    event = ClientWithdrawalFlowEvent.where(client_withdrawal_flow_id: cycle.id).order(:id).last

    assert_equal ClientWithdrawalFlowStatus::RECOVERED, event.to_status_id
    assert_equal "recovered", event.reason
  end

  test "withdrawal termination completes the cycle" do
    now = Time.zone.local(2026, 5, 19, 12, 0, 0)
    cycle = VisitorWithdrawalFlow.create!(visitor: create_visitor)
    cycle.confirm_withdrawal!
    cycle.discard_withdrawal!

    travel_to now do
      cycle.terminate_withdrawal!(reason: "purged")
    end

    cycle.reload

    assert_predicate cycle, :withdrawal_terminated?
    assert_equal now, cycle.completed_at

    event = VisitorWithdrawalFlowEvent.where(visitor_withdrawal_flow_id: cycle.id).order(:id).last

    assert_equal VisitorWithdrawalFlowStatus::TERMINATED, event.to_status_id
    assert_equal "purged", event.reason
  end

  test "withdrawal transitions reject reverse movement" do
    cycle = ClientWithdrawalFlow.create!(client: create_client)
    cycle.confirm_withdrawal!

    error =
      assert_raises(FlowInvalidTransition) do
        cycle.request_withdrawal!
      end

    assert_match(/invalid transition/, error.message)
    assert_equal ClientWithdrawalFlowStatus::CLOSING, cycle.reload.status_id
  end

  test "default_status_id returns REQUESTED status id" do
    assert_equal ClientWithdrawalFlowStatus::REQUESTED, ClientWithdrawalFlow.default_status_id
    assert_equal VisitorWithdrawalFlowStatus::REQUESTED, VisitorWithdrawalFlow.default_status_id
  end

  test "status_name_for returns the correct status name" do
    assert_equal "REQUESTED", ClientWithdrawalFlow.status_name_for(ClientWithdrawalFlowStatus::REQUESTED)
    assert_equal "TERMINATED", VisitorWithdrawalFlow.status_name_for(VisitorWithdrawalFlowStatus::TERMINATED)
  end

  test "can_transition_to? accepts valid next status" do
    cycle = ClientWithdrawalFlow.create!(client: create_client)

    assert cycle.can_transition_to?("CLOSING")
    assert cycle.can_transition_to?(ClientWithdrawalFlowStatus::CLOSING)
  end

  test "terminal and failed statuses require terminal timestamps" do
    recovered = ClientWithdrawalFlow.new(
      client: create_client,
      status_id: ClientWithdrawalFlowStatus::RECOVERED,
    )

    assert_not recovered.valid?
    assert_not_empty recovered.errors[:completed_at]

    failed = VisitorWithdrawalFlow.new(
      visitor: create_visitor,
      status_id: VisitorWithdrawalFlowStatus::FAILED,
    )

    assert_not failed.valid?
    assert_not_empty failed.errors[:failed_at]
  end

  private

  def create_client
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
    ClientMfaStatus.ensure_defaults!

    Client.create!(
      public_id: PublicId.generate,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
      security_mode_id: SecurityModeConfigurable::NORMAL,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
  end

  def create_visitor
    VisitorStatus.ensure_defaults!
    VisitorVisibility.ensure_defaults!
    VisitorMfaStatus.ensure_defaults!

    Visitor.create!(
      public_id: PublicId.generate,
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
      security_mode_id: SecurityModeConfigurable::NORMAL,
      mfa_status_id: VisitorMfaStatus::UNCONFIGURED,
    )
  end
end
