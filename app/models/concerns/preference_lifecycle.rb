# frozen_string_literal: true

module PreferenceLifecycle
  class InvalidTransition < StandardError; end
  PURGE_GRACE_PERIOD = 30.days

  public

  def retire!
    with_lock do
      unless status_id == self.class::ACTIVE_STATUS_ID
        raise InvalidTransition, "only an active preference can be retired"
      end

      update!(status_id: self.class::RETIRED_STATUS_ID)
    end
  end

  def confirm_issuance!(issued_at:, expires_at:)
    unless issued_at.acts_like?(:time) && expires_at.acts_like?(:time) && expires_at > issued_at
      raise ArgumentError, "invalid preference issuance interval"
    end
    raise InvalidTransition, "only an active preference can be issued" unless status_id == self.class::ACTIVE_STATUS_ID

    update!(last_issued_at: issued_at, last_issued_expires_at: expires_at)
  end

  # A passed deadline alone does not authorize deletion: references and holds must also be checked.
  def issuance_retention_elapsed?(now:)
    raise ArgumentError, "preference retention time is required" unless now.acts_like?(:time)

    now >= last_issued_expires_at + PURGE_GRACE_PERIOD
  end

  def issuance_active_at?(now:)
    raise ArgumentError, "preference validity time is required" unless now.acts_like?(:time)

    status_id == self.class::ACTIVE_STATUS_ID && now < last_issued_expires_at
  end
end
