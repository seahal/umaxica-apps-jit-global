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
    now = Time.current
    deactivated = actor.deactivated_at.presence || now

    actor.class.transaction do
      actor.lock!
      ensure_withdrawal_flow_discarded!(now: now)
      actor.update!(
        withdrawal_started_at: actor.withdrawal_started_at.presence || now,
        deactivated_at: deactivated,
        discarded_at: deactivated,
        purged_at: if actor.purged_at.present? && finite_future_time?(actor.purged_at)
                     actor.purged_at
                   else
                     deactivated + RECOVERY_PERIOD
                   end,
      )
      revoke_sessions
    end

    notify(
      "suspended", deactivated_at: actor.deactivated_at, discarded_at: actor.discarded_at,
                   purged_at: actor.purged_at,
    )
    record_occurrence!("withdrawal.deactivated")
    actor
  end

  def recover!
    raise Sign::WithdrawalRecoveryNotAvailableError unless actor.can_recover?
    raise Sign::WithdrawalRecoveryNotAvailableError if privacy_request_blocks_recovery?

    actor.class.transaction do
      actor.lock!
      cancel_received_privacy_requests!
      ensure_withdrawal_flow_recovered!(now: Time.current)
      actor.update!(
        withdrawal_started_at: nil,
        deactivated_at: nil,
        discarded_at: Float::INFINITY,
        purged_at: Float::INFINITY,
        withdrawn_at: nil,
      )
    end

    notify("recovered")
    record_occurrence!("withdrawal.recovered")
    actor
  end

  def terminate!
    raise Sign::InvalidWithdrawalStateError, actor.class.name unless actor.early_terminatable?

    actor.class.transaction do
      actor.lock!
      ensure_withdrawal_flow_terminated!(now: Time.current)
      if actor.respond_to?(:terminated_at=)
        actor.terminated_at = Time.current
        actor.save!(validate: false)
      end
      WithdrawalPersonalDataAnonymizer.call(actor:)
      revoke_sessions
    end

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
    cycle = active_withdrawal_flow || create_withdrawal_flow!(status: "REQUESTED", now: now)
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

  def revoke_sessions
    AuthenticationSessionRevoker.tokens_for(actor).find_each(&:revoke!)
  end

  def finite_future_time?(value)
    return false if value.blank?
    return false if value.respond_to?(:infinite?) && value.infinite?

    value.future?
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
