# typed: false
# frozen_string_literal: true

module FlowSignOut
  extend ActiveSupport::Concern

  include FlowBase

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

  def sign_out_awaiting_expiry?
    cycle_status?(status_id_for("AWAITING_EXPIRY"))
  end

  def sign_out_completed?
    cycle_status?(status_id_for("COMPLETED"))
  end

  def sign_out_failed?
    cycle_status?(status_id_for("FAILED"))
  end

  def request_sign_out!(now: Time.current)
    transition_sign_out_to!(
      "REQUESTED",
      allowed_from: ["NOTHING"],
      changes: { requested_at: now },
      now: now,
    )
  end

  def mark_access_discarded!(now: Time.current)
    transition_sign_out_to!(
      "ACCESS_DISCARDED",
      allowed_from: ["REQUESTED"],
      changes: { access_discarded_at: now },
      now: now,
    )
  end

  def mark_logically_revoked!(now: Time.current)
    transition_sign_out_to!(
      "LOGICALLY_REVOKED",
      allowed_from: ["ACCESS_DISCARDED"],
      changes: { logically_revoked_at: now },
      now: now,
    )
  end

  def await_sign_out_expiry!(now: Time.current)
    transition_sign_out_to!(
      "AWAITING_EXPIRY",
      allowed_from: ["LOGICALLY_REVOKED"],
      now: now,
    )
  end

  def complete_sign_out!(now: Time.current)
    transition_sign_out_to!(
      "COMPLETED",
      allowed_from: ["AWAITING_EXPIRY"],
      changes: { completed_at: now },
      now: now,
    )
  end

  def fail_sign_out!(now: Time.current)
    transition_sign_out_to!(
      "FAILED",
      allowed_from: %w(REQUESTED ACCESS_DISCARDED LOGICALLY_REVOKED AWAITING_EXPIRY),
      changes: { failed_at: now },
      now: now,
    )
  end

  def discard_sign_out!(now: Time.current)
    discard_cycle!(discard_at: now, purge_eligible_at: purge_eligible_at)
  end

  private

  def transition_sign_out_to!(next_status_name, allowed_from:, changes: {}, now:)
    transition_cycle_to!(
      status_id_for(next_status_name),
      allowed_from: status_ids_for(*allowed_from),
      changes: changes,
      now: now,
    )
  end
end
