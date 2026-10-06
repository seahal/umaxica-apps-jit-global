# typed: false
# frozen_string_literal: true

module FlowSignUp
  extend ActiveSupport::Concern

  include FlowBase
  include SignFlowStatusBacked

  included do
    cycle_status_column :status_id
  end

  class_methods do
    def sign_up_status_ids_for(*status_names)
      status_names.filter_map do |status_name|
        status_id_for(status_name)
      rescue KeyError
        nil
      end
    end

    def sign_up_in_progress_status_ids
      sign_up_status_ids_for(
        "STARTED", "CONTACT_PENDING", "CREDENTIAL_PENDING", "CONTACT_VERIFIED",
        "SOCIAL_CALLBACK_PENDING", "GUARDRAIL_PENDING", "CHECKPOINT_PENDING",
        "FINALIZING",
      )
    end

    def sign_up_cancelable_status_ids
      sign_up_status_ids_for(
        "STARTED", "CONTACT_PENDING", "CREDENTIAL_PENDING", "CONTACT_VERIFIED",
        "SOCIAL_CALLBACK_PENDING", "GUARDRAIL_PENDING", "CHECKPOINT_PENDING",
      )
    end

    def sign_up_terminal_status_ids
      sign_up_status_ids_for(
        "COMPLETED", "FAILED", "EXPIRED", "CANCELLED", "HALTED", "FINALIZED", "SIGN_IN_HANDOFF_PENDING",
      )
    end
  end

  def sign_up_started?
    cycle_status?(status_id_for("STARTED"))
  end

  def sign_up_contact_pending?
    cycle_status?(status_id_for("CONTACT_PENDING"))
  end

  def sign_up_credential_pending?
    cycle_status?(status_id_for("CREDENTIAL_PENDING"))
  end

  def sign_up_checkpoint_pending?
    cycle_status?(status_id_for("CHECKPOINT_PENDING"))
  end

  def sign_up_completed?
    cycle_status?(status_id_for("COMPLETED"))
  end

  def sign_up_expired?
    cycle_status?(status_id_for("EXPIRED"))
  end

  def sign_up_cancelled?
    cycle_status?(status_id_for("CANCELLED"))
  rescue KeyError
    false
  end

  def sign_up_halted?
    cycle_status?(status_id_for("HALTED"))
  rescue KeyError
    false
  end

  def sign_up_in_progress?
    self.class.sign_up_in_progress_status_ids.include?(cycle_status_id)
  end

  def sign_up_cancelable?
    self.class.sign_up_cancelable_status_ids.include?(cycle_status_id)
  end

  def sign_up_terminal?
    self.class.sign_up_terminal_status_ids.include?(cycle_status_id)
  end

  def advance_sign_up_to_contact!
    transition_sign_up_to!("CONTACT_PENDING")
  end

  def advance_sign_up_to_credential!
    transition_sign_up_to!("CREDENTIAL_PENDING")
  end

  def verify_sign_up_contact!
    transition_sign_up_to!("CONTACT_VERIFIED")
  end

  def start_sign_up_social_callback!
    transition_sign_up_to!("SOCIAL_CALLBACK_PENDING")
  end

  def advance_sign_up_to_guardrail!
    transition_sign_up_to!("GUARDRAIL_PENDING")
  end

  def advance_sign_up_to_checkpoint!
    transition_sign_up_to!("CHECKPOINT_PENDING")
  end

  def begin_sign_up_finalization!
    transition_sign_up_to!("FINALIZING")
  end

  def complete_sign_up!
    transition_sign_up_to!("COMPLETED")
  end

  def expire_sign_up!
    transition_sign_up_to!("EXPIRED")
  end

  def cancel_sign_up!
    fields = has_attribute?(:cancelled_at) ? [:cancelled_at] : []
    transition_sign_up_to!("CANCELLED", timestamp_fields: fields)
  end

  def halt_sign_up!
    fields = has_attribute?(:failed_at) ? [:failed_at] : []
    transition_sign_up_to!("HALTED", timestamp_fields: fields)
  end

  def discard_sign_up!(now: Time.current)
    discard_cycle!(discard_at: now, purge_eligible_at: purge_eligible_at)
  end

  private

  def transition_sign_up_to!(next_status_name, changes: {}, timestamp_fields: [])
    transition_cycle_to!(
      status_id_for(next_status_name),
      changes: changes,
      timestamp_fields: timestamp_fields,
    )
  end
end
