# frozen_string_literal: true

# Marks expired dispatches indeterminate without retrying a possibly consumed code.
class RpStepUpDispatchRecovery
  DISPATCH_DEADLINE = 60.seconds
  BATCH_SIZE = 100

  class << self
    public

    def call(cell:)
      new(cell:).call
    end
  end

  def initialize(cell:)
    @entry = RpStepUpCellRegistry.fetch(cell)
  end

  public

  def call
    entry.record_class.connected_to(role: :writing) do
      now = entry.record_class.database_now
      expired_pending_count(now) + expired_dispatch_count(now)
    end
  end

  private

  attr_reader :entry

  def state_refs_due_by(now)
    due_state_ids = entry.state_class.joins(:transitions)
      .where(state_id: entry.status_class::DISPATCHING)
      .where(entry.transition_class.table_name => { to_state_id: entry.status_class::DISPATCHING })
      .where("#{entry.transition_class.table_name}.occurred_at <= ?", now - DISPATCH_DEADLINE)
      .distinct.order("#{entry.state_class.table_name}.id").limit(BATCH_SIZE).select(:id)
    entry.state_class.where(id: due_state_ids).order(:id).pluck(:public_id)
  end

  def expired_pending_count(now)
    entry.state_class.where(state_id: entry.status_class::PENDING)
      .where(expires_at: ..now).order(:id).limit(BATCH_SIZE).pluck(:public_id).count do |state_ref|
        result =
          RpStepUpStateTransitionWriter.call(cell: entry.cell, state_ref:) do |state, _session, _binding,
                                                                                              locked_now|
            next unless state.state_id == entry.status_class::PENDING && state.expires_at <= locked_now

            RpStepUpStateTransitionWriter::Decision.new(
              to_status_id: entry.status_class::EXPIRED,
              reason_code: "expired",
              event_type: "step_up.expired",
              payload: nil,
              outcome: :expired,
            )
          end
        result.outcome == :expired
      end
  end

  def expired_dispatch_count(now)
    state_refs_due_by(now).count do |state_ref|
      result =
        RpStepUpStateTransitionWriter.call(cell: entry.cell, state_ref:) do |state, _session, _binding,
                                                                                          locked_now|
          dispatched_at = entry.transition_class.find_by(
            owner_id: state.id,
            to_state_id: entry.status_class::DISPATCHING,
          )&.occurred_at
          next unless state.state_id == entry.status_class::DISPATCHING && dispatched_at &&
            locked_now >= dispatched_at + DISPATCH_DEADLINE

          RpStepUpStateTransitionWriter::Decision.new(
            to_status_id: entry.status_class::INDETERMINATE,
            reason_code: "dispatch_deadline_passed",
            event_type: "step_up.indeterminate",
            payload: nil,
            outcome: :indeterminate,
          )
        end
      result.outcome == :indeterminate
    end
  end
end
