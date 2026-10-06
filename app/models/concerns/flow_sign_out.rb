# typed: false
# frozen_string_literal: true

module FlowSignOut
  extend ActiveSupport::Concern

  include FlowBase
  include SignFlowStatusBacked

  included do
    cycle_status_column :status_id
  end

  def sign_out_nothing?
    cycle_status?(status_id_for("NOTHING"))
  end

  def sign_out_requested?
    cycle_status?(status_id_for("REQUESTED"))
  end

  def sign_out_access_discarded?
    cycle_status?(status_id_for("ACCESS_DISCARDED"))
  end

  def sign_out_logically_revoked?
    cycle_status?(status_id_for("LOGICALLY_REVOKED"))
  end

  def sign_out_completed?
    cycle_status?(status_id_for("COMPLETED"))
  end

  def sign_out_failed?
    cycle_status?(status_id_for("FAILED"))
  end

  def sign_out_expired?
    cycle_status?(status_id_for("EXPIRED"))
  rescue KeyError
    false
  end

  def sign_out_cancelled?
    cycle_status?(status_id_for("CANCELLED"))
  rescue KeyError
    false
  end

  def sign_out_halted?
    cycle_status?(status_id_for("HALTED"))
  rescue KeyError
    false
  end

  def request_sign_out!
    transition_sign_out_to!("REQUESTED", timestamp_fields: [:requested_at])
  end

  def mark_access_discarded!
    transition_sign_out_to!("ACCESS_DISCARDED", timestamp_fields: [:access_discarded_at])
  end

  def mark_logically_revoked!
    transition_sign_out_to!("LOGICALLY_REVOKED", timestamp_fields: [:logically_revoked_at])
  end

  def complete_sign_out!
    transition_sign_out_to!("COMPLETED")
  end

  def expire_sign_out!
    transition_sign_out_to!("EXPIRED")
  end

  def cancel_sign_out!
    transition_sign_out_to!("CANCELLED")
  end

  def halt_sign_out!
    transition_sign_out_to!("HALTED", timestamp_fields: [:failed_at])
  end

  def discard_sign_out!(now: Time.current)
    discard_cycle!(discard_at: now, purge_eligible_at: purge_eligible_at)
  end

  private

  def transition_sign_out_to!(next_status_name, changes: {}, timestamp_fields: [])
    transition_cycle_to!(
      status_id_for(next_status_name),
      changes: changes,
      timestamp_fields: timestamp_fields,
    )
  end
end
