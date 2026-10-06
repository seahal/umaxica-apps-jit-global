# typed: false
# frozen_string_literal: true

require "test_helper"

class SignOutFlowTest < ActiveSupport::TestCase
  SIGN_OUT_CLASSES = [
    ClientSignOutFlow,
    VisitorSignOutFlow,
    OperatorSignOutFlow,
  ].freeze

  test "sign-out cycles inherit from their surface cycle records" do
    assert_operator ClientSignOutFlow, :<, AppTicketRecord
    assert_operator VisitorSignOutFlow, :<, ComTicketRecord
    assert_operator OperatorSignOutFlow, :<, OrgTicketRecord
  end

  test "sign-out status reference tables include nothing as the zero value" do
    SIGN_OUT_CLASSES.each do |cycle_class|
      assert_equal 0, cycle_class::STATUS_MODEL::NOTHING
      assert_includes cycle_class::STATUS_MODEL::DEFAULTS, cycle_class::STATUS_MODEL::NOTHING
      assert_includes cycle_class::STATUS_IDS, cycle_class::STATUS_MODEL::NOTHING
    end
  end

  test "sign-out kind reference tables include nothing as the zero value" do
    SIGN_OUT_CLASSES.each do |cycle_class|
      assert_equal 0, cycle_class::KIND_MODEL::NOTHING
      assert_includes cycle_class::KIND_MODEL::DEFAULTS, cycle_class::KIND_MODEL::NOTHING
      assert_equal cycle_class::KIND_MODEL::NOTHING, cycle_class.default_kind_id
    end
  end

  test "sign-out cycles default to requested status and nothing kind" do
    SIGN_OUT_CLASSES.each do |cycle_class|
      cycle = build_cycle(cycle_class)

      assert_predicate cycle, :valid?, cycle.errors.full_messages.join(", ")
      assert_equal cycle_class::STATUS_MODEL::REQUESTED, cycle.status_id
      assert_equal cycle_class::KIND_MODEL::NOTHING, cycle.kind_id
    end
  end

  test "sign-out cycles reject unknown statuses and kinds" do
    SIGN_OUT_CLASSES.each do |cycle_class|
      invalid_status = build_cycle(cycle_class, status_id: 999)

      assert_not invalid_status.valid?, cycle_class.name
      assert_not_empty invalid_status.errors[:status_id]

      invalid_kind = build_cycle(cycle_class, kind_id: 999)

      assert_not invalid_kind.valid?, cycle_class.name
      assert_not_empty invalid_kind.errors[:kind_id]
    end
  end

  test "sign-out cycles require refresh expiry at or after access expiry" do
    cycle = build_cycle(
      ClientSignOutFlow,
      access_expires_at: Time.zone.local(2026, 5, 19, 11, 0, 0),
      refresh_expires_at: Time.zone.local(2026, 5, 19, 10, 59, 59),
    )

    assert_not cycle.valid?
    assert_not_empty cycle.errors[:refresh_expires_at]
  end

  test "sign-out cycle methods progress through the logout boundary states" do
    now = Time.zone.local(2026, 5, 19, 11, 0, 0)
    cycle = ClientSignOutFlow.create!(cycle_attrs(ClientSignOutFlow))

    travel_to now do
      assert_predicate cycle, :sign_out_requested?

      cycle.mark_access_discarded!

      assert_predicate cycle, :sign_out_access_discarded?
      assert_in_delta ClientSignOutFlow.database_now.to_f, cycle.access_discarded_at.to_f, 2.0

      cycle.mark_logically_revoked!

      assert_predicate cycle, :sign_out_logically_revoked?
      assert_in_delta ClientSignOutFlow.database_now.to_f, cycle.logically_revoked_at.to_f, 2.0

      cycle.complete_sign_out!

      assert_predicate cycle, :sign_out_completed?
      assert_in_delta ClientSignOutFlow.database_now.to_f, cycle.completed_at.to_f, 2.0
    end
  end

  test "request_sign_out! sets the requested state from nothing" do
    now = Time.zone.local(2026, 5, 19, 11, 0, 0)
    cycle = ClientSignOutFlow.create!(cycle_attrs(ClientSignOutFlow).merge(status_id: ClientSignOutFlowStatus::NOTHING))

    travel_to now do
      cycle.request_sign_out!
    end

    assert_predicate cycle, :sign_out_requested?
    assert_in_delta ClientSignOutFlow.database_now.to_f, cycle.requested_at.to_f, 2.0
  end

  test "sign-out cycle cannot use the private transition writer" do
    cycle = ClientSignOutFlow.create!(cycle_attrs(ClientSignOutFlow))
    cycle.mark_access_discarded!

    assert_not_respond_to cycle, :transition_cycle_to!
    assert_equal ClientSignOutFlowStatus::ACCESS_DISCARDED, cycle.reload.status_id
  end

  test "discard_sign_out! marks the cycle discarded without changing the status" do
    cycle = ClientSignOutFlow.create!(cycle_attrs(ClientSignOutFlow))

    cycle.discard_sign_out!

    assert_predicate cycle, :lapsed?
    assert_predicate cycle, :sign_out_requested?
  end

  test "sign-out cycles can halt before completion" do
    now = Time.zone.local(2026, 5, 19, 11, 0, 0)
    cycle = ClientSignOutFlow.create!(cycle_attrs(ClientSignOutFlow))

    travel_to now do
      cycle.halt_sign_out!
    end

    assert_predicate cycle, :sign_out_halted?
    assert_in_delta ClientSignOutFlow.database_now.to_f, cycle.failed_at.to_f, 2.0
  end

  test "status_name_for returns the name for a given status id" do
    SIGN_OUT_CLASSES.each do |cycle_class|
      id = cycle_class.default_status_id

      assert_equal "REQUESTED", cycle_class.status_name_for(id)
    end
  end

  test "kind_name_for returns the name for a given kind id" do
    SIGN_OUT_CLASSES.each do |cycle_class|
      id = cycle_class.default_kind_id

      assert_equal "NOTHING", cycle_class.kind_name_for(id)
    end
  end

  test "status_ids_for returns an array of status ids for the given names" do
    ids = ClientSignOutFlow.status_ids_for("REQUESTED", "COMPLETED")

    assert_equal ClientSignOutFlow.status_id_for("REQUESTED"), ids[0]
    assert_equal ClientSignOutFlow.status_id_for("COMPLETED"), ids[1]
  end

  test "instance status_ids_for delegates to the class method" do
    cycle = build_cycle(ClientSignOutFlow)
    ids = cycle.status_ids_for("REQUESTED", "COMPLETED")

    assert_equal ClientSignOutFlow.status_ids_for("REQUESTED", "COMPLETED"), ids
  end

  test "can_transition_to? returns false for invalid transitions" do
    cycle = ClientSignOutFlow.create!(cycle_attrs(ClientSignOutFlow))

    assert_not cycle.can_transition_to?("COMPLETED")
  end

  test "arbitrary sign-out transitions are not public" do
    cycle = ClientSignOutFlow.create!(cycle_attrs(ClientSignOutFlow))

    assert_not_respond_to cycle, :transition_to!
  end

  test "can_transition_to? accepts an integer status id" do
    cycle = ClientSignOutFlow.create!(cycle_attrs(ClientSignOutFlow))
    requested_id = ClientSignOutFlow.status_id_for("REQUESTED")

    # Passing the current status id as an integer -- this is not a real transition
    # but exercises the normalize_status_id integer branch before the guard.
    assert_not cycle.can_transition_to?(requested_id)
  end

  test "completed_status_has_completed_at adds error when completed_at is blank" do
    completed_id = ClientSignOutFlow.status_id_for("COMPLETED")
    cycle = build_cycle(ClientSignOutFlow, status_id: completed_id)
    cycle.valid?

    assert_includes cycle.errors[:completed_at], "must be present for completed cycles"
  end

  test "awaiting expiry remains an absorbing tombstone status" do
    awaiting_id = ClientSignOutFlow.status_id_for("AWAITING_EXPIRY")
    awaiting = ClientSignOutFlow.create!(cycle_attrs(ClientSignOutFlow).merge(status_id: awaiting_id))

    assert_not_respond_to awaiting, :sign_out_awaiting_expiry?
    assert_not awaiting.can_transition_to?("COMPLETED")
  end

  test "complete_sign_out! sets completed_at when reaching the completed status" do
    now = Time.zone.local(2026, 5, 19, 12, 0, 0)
    logically_revoked_id = ClientSignOutFlow.status_id_for("LOGICALLY_REVOKED")
    cycle = ClientSignOutFlow.create!(cycle_attrs(ClientSignOutFlow).merge(status_id: logically_revoked_id))

    travel_to now do
      cycle.complete_sign_out!
    end

    assert_predicate cycle, :sign_out_completed?
    assert_in_delta ClientSignOutFlow.database_now.to_f, cycle.completed_at.to_f, 2.0
  end

  private

  def build_cycle(cycle_class, **overrides)
    cycle_class.new(cycle_attrs(cycle_class).merge(overrides))
  end

  def cycle_attrs(cycle_class)
    {
      principal_id: 123,
      status_id: cycle_class.default_status_id,
      kind_id: cycle_class.default_kind_id,
      refresh_token_family_id: "family-#{cycle_class.name}",
      requested_at: Time.current,
      access_expires_at: 5.minutes.from_now,
      refresh_expires_at: 1.hour.from_now,
      return_to: "/dashboard",
    }
  end
end
