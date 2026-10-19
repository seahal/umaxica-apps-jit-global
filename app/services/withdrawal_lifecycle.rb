# typed: false
# frozen_string_literal: true

class WithdrawalLifecycle
  RECOVERY_PERIOD = Withdrawable::WITHDRAWAL_RECOVERY_PERIOD

  def self.start!(actor:, current_session_public_id: nil, request: nil)
    new(actor:, current_session_public_id:, request:).start!
  end

  def self.suspend!(actor:, current_session_public_id: nil, request: nil)
    new(actor:, current_session_public_id:, request:).suspend!
  end

  def self.recover!(actor:, request: nil)
    new(actor:, request:).recover!
  end

  def self.terminate!(actor:, request: nil)
    new(actor:, request:).terminate!
  end

  def initialize(actor:, current_session_public_id: nil, request: nil)
    @actor = actor
    @current_session_public_id = current_session_public_id
    @request = request
  end

  def start!
    now = Time.current

    actor.class.transaction do
      actor.lock!
      ensure_withdrawal_flow_requested!(now: now)
    end

    notify("requested")
    record_occurrence!("withdrawal.requested")
    actor
  end

  def suspend!
    stop_event = nil
    deactivated = nil
    timing_policy = Umaxica::Withdrawal::TimingPolicyValue.current

    actor.class.transaction do
      actor.lock!
      now = actor.class.database_now
      deactivated = actor.deactivated_at.presence || now
      ensure_withdrawal_flow_discarded!(now: now)
      deactivated = actor.deactivated_at.presence || deactivated
      recovery_available_at = persisted_or_legacy_deadline(
        :recovery_available_at,
        deactivated: deactivated,
        legacy_delay: Withdrawable::WITHDRAWAL_RECOVERY_DELAY,
        configured_delay: timing_policy.recovery_delay,
      )
      early_termination_available_at = persisted_or_legacy_deadline(
        :early_termination_available_at,
        deactivated: deactivated,
        legacy_delay: Withdrawable::WITHDRAWAL_EARLY_TERMINATION_DELAY,
        configured_delay: timing_policy.early_termination_delay,
      )
      actor.update!(
        withdrawal_started_at: actor.withdrawal_started_at.presence || now,
        deactivated_at: deactivated,
        recovery_available_at: recovery_available_at,
        early_termination_available_at: early_termination_available_at,
        discard_at: deactivated,
        purge_eligible_at: if actor.purge_eligible_at.present? && finite_time?(actor.purge_eligible_at)
                             actor.purge_eligible_at
                           else
                             deactivated + timing_policy.retention_period
                           end,
      )
      stop_event = IdentityAuthenticationStopRecorder.call(actor:, reason: "withdrawal_suspend")
    end
    # The OP applies the stop only after the Zenith commit (one.md section 7.5).
    OpIdentityEventInvalidator.deliver(event: stop_event)

    notify(
      "suspended", deactivated_at: actor.deactivated_at, discard_at: actor.discard_at,
                   purge_eligible_at: actor.purge_eligible_at,
    )
    record_occurrence!("withdrawal.deactivated")
    actor
  end

  def recover!
    actor.class.transaction do
      actor.lock!
      # Re-evaluate all time and retention predicates after taking the principal lock. A
      # pre-lock check lets recovery race a purge or a newly-created privacy request.
      now = actor.class.database_now
      raise Sign::WithdrawalRecoveryNotAvailableError unless actor.can_recover?(now: now)
      raise Sign::WithdrawalRecoveryNotAvailableError if privacy_request_blocks_recovery?

      cancel_received_privacy_requests!
      ensure_withdrawal_flow_recovered!(now: now)
      actor.update!(
        withdrawal_started_at: nil,
        deactivated_at: nil,
        recovery_available_at: nil,
        early_termination_available_at: nil,
        discard_at: Float::INFINITY,
        purge_eligible_at: Float::INFINITY,
        withdrawn_at: nil,
      )
    end

    notify("recovered")
    record_occurrence!("withdrawal.recovered")
    actor
  end

  def terminate!
    stop_event = nil

    actor.class.transaction do
      actor.lock!
      # The deadline and all deletion guards must be checked while holding the same lock as the
      # terminal write. Otherwise a concurrent recovery or hold can be defeated by a stale check.
      now = actor.class.database_now
      raise Sign::InvalidWithdrawalStateError, actor.class.name unless actor.early_terminatable?(now: now)
      raise Sign::InvalidWithdrawalStateError, actor.class.name if active_retention_hold?
      raise Sign::InvalidWithdrawalStateError, actor.class.name if enforcement_blocks_termination?

      ensure_withdrawal_flow_terminated!(now: now)
      WithdrawalPersonalDataAnonymizer.call(actor:)
      if actor.respond_to?(:terminated_at=)
        actor.terminated_at = actor.class.database_now
        actor.save!(validate: false)
      end
      stop_event = IdentityAuthenticationStopRecorder.call(actor:, reason: "withdrawal_terminate")
    end
    OpIdentityEventInvalidator.deliver(event: stop_event)

    notify("terminated", terminated_at: actor.try(:terminated_at))
    record_occurrence!("withdrawal.terminated")
    actor
  end

  private

  attr_reader :actor, :current_session_public_id, :request

  def ensure_withdrawal_flow_requested!(now:)
    cycle = active_withdrawal_flow || create_withdrawal_flow!(status: "REQUESTED", now: now)
    return cycle if cycle.withdrawal_requested?
    return cycle if cycle.withdrawal_closing? || cycle.withdrawal_discarded?

    raise Sign::InvalidWithdrawalStateError, withdrawal_flow_class.status_name_for(cycle.status_id)
  end

  def ensure_withdrawal_flow_discarded!(now:)
    cycle = active_withdrawal_flow
    raise Sign::InvalidWithdrawalStateError, "REQUESTED" unless cycle

    cycle.confirm_withdrawal!(
      **withdrawal_flow_event_attrs(
        now: now,
        reason: "confirmed",
      ),
    ) if cycle.withdrawal_requested?
    cycle.discard_withdrawal!(
      **withdrawal_flow_event_attrs(
        now: now,
        reason: "discarded",
      ),
    ) if cycle.withdrawal_closing?
    cycle
  end

  def ensure_withdrawal_flow_recovered!(now:)
    # Recovery operates on an already-suspended principal. Legacy suspended rows may predate a
    # flow row, so materialize the discarded cycle here; the deactivation itself still requires a
    # persisted REQUESTED cycle in ensure_withdrawal_flow_discarded!.
    cycle = active_withdrawal_flow || create_withdrawal_flow!(status: "DISCARDED", now: now)
    cycle.recover_withdrawal!(
      **withdrawal_flow_event_attrs(
        now: now,
        reason: "recovered",
      ),
    ) if cycle.withdrawal_discarded?
    cycle
  end

  def ensure_withdrawal_flow_terminated!(now:)
    # As with recovery, an already-suspended legacy principal may not have a retained flow row.
    # Termination remains protected by the locked deadline, retention hold and ceremony checks.
    cycle = active_withdrawal_flow || create_withdrawal_flow!(status: "DISCARDED", now: now)
    cycle.terminate_withdrawal!(
      **withdrawal_flow_event_attrs(
        now: now,
        reason: "terminated",
      ),
    ) if cycle.withdrawal_discarded?
    cycle
  end

  def active_withdrawal_flow
    withdrawal_flow_scope.active.recent_first.first
  end

  def create_withdrawal_flow!(status:, now:)
    withdrawal_flow_class.create!(
      withdrawal_flow_actor_key => actor,
      :status_id => withdrawal_flow_class.status_id_for(status),
      :began_at => actor.withdrawal_started_at.presence || now,
    )
  end

  def withdrawal_flow_scope
    actor.public_send(withdrawal_flow_association)
  end

  def withdrawal_flow_class
    case actor.class.name
    when "Client" then ClientWithdrawalFlow
    when "Visitor" then VisitorWithdrawalFlow
    else
      raise Sign::InvalidWithdrawalStateError, actor.class.name
    end
  end

  def withdrawal_flow_association
    case actor.class.name
    when "Client" then :client_withdrawal_flows
    when "Visitor" then :visitor_withdrawal_flows
    else
      raise Sign::InvalidWithdrawalStateError, actor.class.name
    end
  end

  def withdrawal_flow_actor_key
    case actor.class.name
    when "Client" then :client
    when "Visitor" then :visitor
    else
      raise Sign::InvalidWithdrawalStateError, actor.class.name
    end
  end

  def withdrawal_flow_event_attrs(now:, reason:)
    {
      now: now,
      token_public_id: current_session_public_id,
      reason: reason,
    }
  end

  def finite_time?(value)
    value.present? && !(value.respond_to?(:infinite?) && value.infinite?)
  end

  def persisted_or_legacy_deadline(attribute, deactivated:, legacy_delay:, configured_delay:)
    persisted = actor[attribute] if actor.has_attribute?(attribute)
    return persisted if persisted.present?

    return deactivated + legacy_delay if actor.deactivated_at.present?

    deactivated + configured_delay
  end

  def privacy_requests
    case actor
    when Client then actor.client_privacy_requests
    when Visitor then actor.visitor_privacy_requests
    else
      raise Sign::InvalidWithdrawalStateError, actor.class.name
    end
  end

  def privacy_request_blocks_recovery?
    privacy_requests.open_for_recovery_block.exists?
  end

  def active_retention_hold?
    case actor
    when Client then actor.client_retention_holds.active_at(actor.class.database_now).exists?
    when Visitor then actor.visitor_retention_holds.active_at(actor.class.database_now).exists?
    else
      raise Sign::InvalidWithdrawalStateError, actor.class.name
    end
  end

  def enforcement_blocks_termination?
    case actor
    when Client
      AppEnforcementCase.principal_effect_blocking?(actor.public_id, :withdrawal_purge_blocked) ||
        AppEnforcementCase.principal_effect_blocking?(actor.public_id, :principal_hard_delete_blocked)
    when Visitor
      ComEnforcementCase.principal_effect_blocking?(actor.public_id, :withdrawal_purge_blocked) ||
        ComEnforcementCase.principal_effect_blocking?(actor.public_id, :principal_hard_delete_blocked)
    else
      raise Sign::InvalidWithdrawalStateError, actor.class.name
    end
  end

  def cancel_received_privacy_requests!
    privacy_requests.received.find_each do |privacy_request|
      privacy_request.cancel_from_recovery!
      record_occurrence!("privacy_erasure.cancelled", privacy_request_public_id: privacy_request.public_id)
    end
  end

  def record_occurrence!(event_type, context = {})
    WithdrawalOccurrenceRecording.record!(
      subject: actor,
      event_type: event_type,
      request: request,
      context: context.merge(session_public_id: current_session_public_id.to_s),
    )
  end

  def notify(state, payload = {})
    Rails.logger.info(
      JitLogEvent.format(
        "#{actor_event_prefix}.withdrawal.#{state}",
        actor_id_key => actor.id,
        :ip_address => request&.remote_ip,
        **payload,
      ),
    )
  end

  def actor_event_prefix
    actor.is_a?(Visitor) ? "visitor" : "user"
  end

  def actor_id_key
    actor.is_a?(Visitor) ? :visitor_id : :user_id
  end
end
