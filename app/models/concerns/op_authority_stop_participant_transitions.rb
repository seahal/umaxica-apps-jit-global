# typed: false
# frozen_string_literal: true

# The named lifecycle writer for an OP authority-stop delivery participant.
module OpAuthorityStopParticipantTransitions
  public

  def claim_delivery!(lease_seconds:)
    raise ArgumentError, "lease_seconds must be positive" unless lease_seconds.is_a?(Integer) && lease_seconds.positive?

    with_delivery_lock do
      if pending_delivery?
        now = self.class.database_now
        if deadline_at <= now
          expire_pending_delivery!(now)
          false
        elsif next_attempt_at > now || lease_expires_at > now
          false
        else
          update!(lease_expires_at: now + lease_seconds, delivery_attempts: delivery_attempts + 1)
          true
        end
      else
        false
      end
    end
  end

  def renew_delivery_lease!(lease_seconds:)
    raise ArgumentError, "lease_seconds must be positive" unless lease_seconds.is_a?(Integer) && lease_seconds.positive?

    with_delivery_lock do
      if pending_delivery?
        now = self.class.database_now
        if deadline_at <= now
          expire_pending_delivery!(now)
          false
        else
          update!(lease_expires_at: now + lease_seconds)
          true
        end
      else
        false
      end
    end
  end

  def record_delivery_result!(outcome:, retry_delay_seconds: nil)
    unless outcome == :acknowledged || (outcome.is_a?(String) && outcome.present?)
      raise ArgumentError, "delivery outcome must be acknowledged or a non-empty outcome code"
    end
    if retry_delay_seconds && (!retry_delay_seconds.is_a?(Integer) || !retry_delay_seconds.positive?)
      raise ArgumentError, "retry delay must be a positive integer"
    end

    with_delivery_lock do
      if pending_delivery?
        now = self.class.database_now
        if deadline_at <= now
          expire_pending_delivery!(now)
          :expired
        elsif outcome == :acknowledged
          raise ArgumentError, "acknowledgment cannot include a retry delay" if retry_delay_seconds

          update!(
            status_id: OpAuthorityStopReference.participant_status_id("acknowledged"),
            lease_expires_at: now, last_outcome: "acknowledged",
          )
          :acknowledged
        elsif retry_delay_seconds
          update!(next_attempt_at: now + retry_delay_seconds, lease_expires_at: now, last_outcome: outcome)
          :retry_scheduled
        else
          update!(
            status_id: OpAuthorityStopReference.participant_status_id("refused"),
            lease_expires_at: now, last_outcome: outcome,
          )
          :refused
        end
      else
        :stale
      end
    end
  end

  def expire_delivery_if_due!
    with_delivery_lock do
      if pending_delivery?
        now = self.class.database_now
        if deadline_at > now
          false
        else
          expire_pending_delivery!(now)
          true
        end
      else
        false
      end
    end
  end

  private

  def with_delivery_lock(&)
    self.class.connection_class_for_self.connected_to(role: :writing) { with_lock(&) }
  end

  def pending_delivery?
    status_id == OpAuthorityStopReference.participant_status_id("pending")
  end

  def expire_pending_delivery!(now)
    update!(
      status_id: OpAuthorityStopReference.participant_status_id("expired"),
      lease_expires_at: now, last_outcome: "expired",
    )
  end
end
