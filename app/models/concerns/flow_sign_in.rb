# typed: false
# frozen_string_literal: true

module FlowSignIn
  extend ActiveSupport::Concern

  include FlowBase

  included do
    cycle_status_column :state_id
  end

  def sign_in_primary_pending?
    cycle_status?(state_id_for("PRIMARY_PENDING"))
  end

  def sign_in_mfa_pending?
    cycle_status?(state_id_for("MFA_PENDING"))
  end

  def sign_in_guardrail_pending?
    cycle_status?(state_id_for("GUARDRAIL_PENDING"))
  end

  def sign_in_session_issuance_pending?
    cycle_status?(state_id_for("SESSION_ISSUANCE_PENDING"))
  end

  def sign_in_checkpoint_pending?
    cycle_status?(state_id_for("CHECKPOINT_PENDING"))
  end

  def sign_in_selector_pending?
    cycle_status?(state_id_for("SELECTOR_PENDING"))
  end

  def sign_in_completed?
    cycle_status?(state_id_for("COMPLETED"))
  end

  def sign_in_failed?
    cycle_status?(state_id_for("FAILED"))
  end

  def sign_in_expired?
    cycle_status?(state_id_for("EXPIRED"))
  end

  def sign_in_cancelled?
    cycle_status?(state_id_for("CANCELLED"))
  end

  def sign_in_halted?
    cycle_status?(state_id_for("HALTED"))
  end

  def advance_sign_in_to_mfa!
    transition_sign_in_to!("MFA_PENDING")
  end

  def advance_sign_in_to_guardrail!
    transition_sign_in_to!("GUARDRAIL_PENDING")
  end

  def advance_sign_in_to_session_issuance!(changes: {})
    transition_sign_in_to!("SESSION_ISSUANCE_PENDING", changes: changes)
  end

  def advance_sign_in_to_checkpoint!
    transition_sign_in_to!("CHECKPOINT_PENDING")
  end

  def advance_sign_in_to_selector!
    transition_sign_in_to!("SELECTOR_PENDING")
  end

  def complete_sign_in!
    transition_sign_in_to!("COMPLETED")
  end

  def expire_sign_in!
    transition_sign_in_to!("EXPIRED")
  end

  def cancel_sign_in!
    transition_sign_in_to!("CANCELLED")
  end

  def halt_sign_in!
    transition_sign_in_to!("HALTED")
  end

  def discard_sign_in!(now: Time.current)
    discard_cycle!(discard_at: now, purge_eligible_at: purge_eligible_at)
  end

  private

  def transition_sign_in_to!(next_status_name, changes: {}, timestamp_fields: [])
    transition_cycle_to!(
      state_id_for(next_status_name),
      changes: changes,
      timestamp_fields: timestamp_fields,
    )
  end
end
