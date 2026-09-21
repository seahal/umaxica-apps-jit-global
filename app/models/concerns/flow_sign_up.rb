# typed: false
# frozen_string_literal: true

module FlowSignUp
  extend ActiveSupport::Concern

  include FlowBase

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
        "STARTED",
        "CONTACT_PENDING",
        "CREDENTIAL_PENDING",
        "CONTACT_VERIFIED",
        "SOCIAL_CALLBACK_PENDING",
        "GUARDRAIL_PENDING",
        "CHECKPOINT_PENDING",
        "FINALIZING",
        "FINALIZED",
        "SIGN_IN_HANDOFF_PENDING",
      )
    end

    def sign_up_cancelable_status_ids
      sign_up_status_ids_for(
        "STARTED",
        "CONTACT_PENDING",
        "CREDENTIAL_PENDING",
        "CONTACT_VERIFIED",
        "SOCIAL_CALLBACK_PENDING",
        "GUARDRAIL_PENDING",
        "CHECKPOINT_PENDING",
      )
    end

    def sign_up_terminal_status_ids
      sign_up_status_ids_for("COMPLETED", "FAILED", "EXPIRED", "CANCELLED")
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

  def sign_up_cancelled?
    cycle_status?(status_id_for("CANCELLED"))
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

  def advance_sign_up_to_contact!(now: Time.current)
    transition_sign_up_to!("CONTACT_PENDING", step: "contact", allowed_from: ["STARTED"], now: now)
  end

  def advance_sign_up_to_credential!(now: Time.current)
    transition_sign_up_to!(
      "CREDENTIAL_PENDING",
      step: "credential",
      allowed_from: ["STARTED", "CONTACT_PENDING"],
      now: now,
    )
  end

  def advance_sign_up_to_checkpoint!(now: Time.current)
    transition_sign_up_to!(
      "CHECKPOINT_PENDING",
      step: "checkpoint",
      allowed_from: %w(STARTED CONTACT_PENDING CREDENTIAL_PENDING),
      now: now,
    )
  end

  def complete_sign_up!(step: "completed", now: Time.current)
    changes = { step: step }
    changes[:completed_at] = now if has_attribute?(:completed_at)

    transition_cycle_to!(
      status_id_for("COMPLETED"),
      allowed_from: status_ids_for("STARTED", "CONTACT_PENDING", "CREDENTIAL_PENDING", "CHECKPOINT_PENDING"),
      changes: changes,
      now: now,
    )
  end

  def discard_sign_up!(now: Time.current)
    discard_cycle!(discard_at: now, purge_eligible_at: purge_eligible_at)
  end

  private

  def transition_sign_up_to!(next_status_name, step:, allowed_from:, now:)
    transition_cycle_to!(
      status_id_for(next_status_name),
      allowed_from: status_ids_for(*allowed_from),
      changes: { step: step },
      now: now,
    )
  end
end
