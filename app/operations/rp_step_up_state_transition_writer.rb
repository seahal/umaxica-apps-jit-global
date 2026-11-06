# frozen_string_literal: true

# Serializes RP step-up state changes with the cell session and sid logout anchor.
class RpStepUpStateTransitionWriter
  Decision = Data.define(:to_status_id, :reason_code, :event_type, :payload, :outcome)
  Result = Data.define(:outcome, :state_ref, :status_id, :occurred_at)

  ALLOWED_TRANSITIONS = {
    [RpStepUpStateStatus::PENDING, RpStepUpStateStatus::DISPATCHING] => [%w(dispatch_started).freeze, nil],
    [RpStepUpStateStatus::PENDING, RpStepUpStateStatus::CANCELLED] =>
      [%w(user_cancelled).freeze, "step_up.cancelled"],
    [RpStepUpStateStatus::PENDING, RpStepUpStateStatus::EXPIRED] => [%w(expired).freeze, "step_up.expired"],
    [RpStepUpStateStatus::PENDING, RpStepUpStateStatus::REFUSED] => [%w(op_error).freeze, "step_up.refused"],
    [RpStepUpStateStatus::DISPATCHING, RpStepUpStateStatus::INSTALLED] =>
      [%w(completed).freeze, "step_up.installed"],
    [RpStepUpStateStatus::DISPATCHING, RpStepUpStateStatus::REFUSED] =>
      [%w(op_error generation_superseded session_invalid).freeze, "step_up.refused"],
    [RpStepUpStateStatus::DISPATCHING, RpStepUpStateStatus::INDETERMINATE] =>
      [%w(exchange_timeout dispatch_deadline_passed).freeze, "step_up.indeterminate"],
  }.freeze

  class << self
    public

    def call(cell:, state_ref:, &)
      new(cell:, state_ref:).call(&)
    end
  end

  def initialize(cell:, state_ref:)
    @entry = RpStepUpCellRegistry.fetch(cell)
    @state_ref = state_ref
  end

  public

  def call
    raise ArgumentError, "RP step-up transition requires a decision block" unless block_given?

    validate_state_ref!
    entry.record_class.connected_to(role: :writing) do
      entry.record_class.transaction do
        state, session, binding = lock_state_and_session!
        next stale_result unless state && session && binding

        now = entry.record_class.database_now
        next stale_result unless ALLOWED_TRANSITIONS.keys.any? { |from, _to| from == state.state_id }

        decision = yield(state, session, binding, now)
        next unchanged_result(state) unless decision

        validate_decision!(state, decision)
        from_status_id = state.state_id
        state.update!(state_id: decision.to_status_id)
        entry.transition_class.create!(
          owner: state,
          from_state_id: from_status_id,
          to_state_id: decision.to_status_id,
          reason_code: decision.reason_code,
          occurred_at: now,
        )
        write_audit!(state:, session:, binding:, decision:, now:)
        Result.new(outcome: decision.outcome, state_ref: state.public_id, status_id: state.state_id, occurred_at: now)
      end
    end
  end

  private

  attr_reader :entry, :state_ref

  def validate_state_ref!
    return if state_ref.is_a?(String) && state_ref.length == 21

    raise ArgumentError, "RP step-up state reference is invalid"
  end

  def lock_state_and_session!
    candidate = entry.state_class.find_by(public_id: state_ref)
    return unless candidate

    session = entry.session_class.find_by(id: candidate.rp_session_id)
    return unless session

    binding = entry.binding_class.lock.find_by(id: session.op_session_binding_id)
    return unless binding

    session.lock!
    state = entry.state_class.lock.find_by(id: candidate.id)
    return unless session.op_session_binding_id == binding.id && state&.rp_session_id == session.id

    [state, session, binding]
  end

  def validate_decision!(state, decision)
    unless decision.is_a?(Decision)
      raise ArgumentError, "RP step-up transition requires a typed decision"
    end

    transition = [state.state_id, decision.to_status_id]
    expected_reasons, expected_event =
      ALLOWED_TRANSITIONS.fetch(transition) do
        raise ArgumentError, "RP step-up transition is not allowed"
      end
    unless decision.event_type == expected_event && expected_reasons.include?(decision.reason_code) &&
        StepUpAuditCodesRegistry::REASON_CODES.include?(decision.reason_code)
      raise ArgumentError, "RP step-up transition decision does not match its closed contract"
    end
  end

  def write_audit!(state:, session:, binding:, decision:, now:)
    return unless decision.event_type

    identity = entry.identity_binding_class.find_by(id: binding.identity_binding_id)
    raise ActiveRecord::RecordNotFound, "RP step-up identity binding is unavailable" unless identity

    payload = decision.payload || payload_for(state:, session:, binding:, decision:)
    StepUpAuditOutboxWriter.call(
      source_key: entry.audit_source_key,
      event_type: decision.event_type,
      realm: entry.cell.realm.upcase,
      client_id: entry.cell.client_id,
      subject_ref: identity.subject,
      context_ref: state.public_id,
      reason_code: decision.reason_code,
      payload: payload,
      occurred_at: now,
    )
  end

  def payload_for(state:, session:, binding:, decision:)
    case decision.event_type
    when "step_up.cancelled", "step_up.expired"
      { rp_state_ref: state.public_id }
    when "step_up.refused", "step_up.indeterminate"
      { rp_state_ref: state.public_id, failure_code: decision.reason_code }
    when "step_up.installed"
      {
        rp_state_ref: state.public_id,
        grant_ref: binding.sid,
        installed_generation: session.installed_generation,
      }
    else
      raise ArgumentError, "RP step-up event payload is not registered"
    end
  end

  def stale_result
    Result.new(outcome: :stale, state_ref:, status_id: nil, occurred_at: nil)
  end

  def unchanged_result(state)
    Result.new(outcome: :unchanged, state_ref: state.public_id, status_id: state.state_id, occurred_at: nil)
  end
end
