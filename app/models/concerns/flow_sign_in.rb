# typed: false
# frozen_string_literal: true

module FlowSignIn
  extend ActiveSupport::Concern

  include FlowBase

  included do
    cycle_status_column :status_id
  end

  def sign_in_primary_pending?
    cycle_status?(status_id_for("PRIMARY_PENDING"))
  end

  def sign_in_mfa_pending?
    cycle_status?(status_id_for("MFA_PENDING"))
  end

  def sign_in_session_limit_pending?
    cycle_status?(status_id_for("SESSION_LIMIT_PENDING"))
  end

  def sign_in_guardrail_pending?
    cycle_status?(status_id_for("GUARDRAIL_PENDING"))
  end

  def sign_in_session_issuance_pending?
    cycle_status?(status_id_for("SESSION_ISSUANCE_PENDING"))
  end

  def sign_in_checkpoint_pending?
    cycle_status?(status_id_for("CHECKPOINT_PENDING"))
  end

  def sign_in_selector_pending?
    cycle_status?(status_id_for("SELECTOR_PENDING"))
  end

  # Legacy compatibility states from the former post-issuance flow. New
  # sign-in cycles issue the active session only after selector and complete
  # from SESSION_ISSUANCE_PENDING.
  def sign_in_dashboard_pending?
    cycle_status?(status_id_for("DASHBOARD_PENDING"))
  end

  def sign_in_return_pending?
    cycle_status?(status_id_for("RETURN_PENDING"))
  end

  def sign_in_completed?
    cycle_status?(status_id_for("COMPLETED"))
  end

  def sign_in_failed?
    cycle_status?(status_id_for("FAILED"))
  end

  def advance_sign_in_to_mfa!(now: Time.current)
    transition_sign_in_to!("MFA_PENDING", step: "mfa", allowed_from: ["PRIMARY_PENDING"], now: now)
  end

  def advance_sign_in_to_session_limit!(now: Time.current)
    transition_sign_in_to!(
      "SESSION_LIMIT_PENDING",
      step: "session_limit",
      allowed_from: %w(PRIMARY_PENDING MFA_PENDING SESSION_ISSUANCE_PENDING),
      now: now,
    )
  end

  def advance_sign_in_to_guardrail!(now: Time.current)
    transition_sign_in_to!(
      "GUARDRAIL_PENDING",
      step: "guardrail",
      allowed_from: %w(PRIMARY_PENDING MFA_PENDING SESSION_LIMIT_PENDING),
      now: now,
    )
  end

  def advance_sign_in_to_session_issuance!(now: Time.current, changes: {})
    transition_sign_in_to!(
      "SESSION_ISSUANCE_PENDING",
      step: "session_issuance",
      allowed_from: ["SELECTOR_PENDING"],
      now: now,
      changes: changes,
    )
  end

  def advance_sign_in_to_checkpoint!(now: Time.current)
    transition_sign_in_to!(
      "CHECKPOINT_PENDING",
      step: "checkpoint",
      allowed_from: ["GUARDRAIL_PENDING"],
      now: now,
    )
  end

  def advance_sign_in_to_selector!(now: Time.current)
    transition_sign_in_to!(
      "SELECTOR_PENDING",
      step: "selector",
      allowed_from: ["CHECKPOINT_PENDING"],
      now: now,
    )
  end

  def advance_sign_in_to_dashboard!(now: Time.current)
    complete_sign_in!(step: "dashboard", now: now)
  end

  # Legacy transition retained for pre-selector cycles and tests that still
  # exercise the old dashboard/return participant chain.
  def advance_sign_in_to_return!(now: Time.current)
    transition_sign_in_to!(
      "RETURN_PENDING",
      step: "return_to",
      allowed_from: ["DASHBOARD_PENDING"],
      now: now,
    )
  end

  def complete_sign_in!(step: "completed", now: Time.current)
    changes = { step: step, state: "COMPLETED" }
    changes[:completed_at] = now if has_attribute?(:completed_at)

    transition_cycle_to!(
      status_id_for("COMPLETED"),
      allowed_from: status_ids_for(
        "SESSION_ISSUANCE_PENDING", "SESSION_LIMIT_PENDING", "DASHBOARD_PENDING",
        "RETURN_PENDING",
      ),
      changes: changes,
      now: now,
    )
  end

  def fail_sign_in!(now: Time.current)
    transition_sign_in_to!(
      "FAILED",
      step: "failed",
      allowed_from: %w(
        PRIMARY_PENDING
        MFA_PENDING
        SESSION_LIMIT_PENDING
        GUARDRAIL_PENDING
        SESSION_ISSUANCE_PENDING
        CHECKPOINT_PENDING
        SELECTOR_PENDING
        DASHBOARD_PENDING
        RETURN_PENDING
      ),
      now: now,
    )
  end

  def transition_to!(next_status, step: nil, now: Time.current)
    _ = step
    next_status_id = normalize_sign_in_status_id(next_status)
    unless self.class::TRANSITIONS.fetch(status_id, []).include?(next_status_id)
      raise ArgumentError, "invalid transition from #{status_id.inspect} to #{next_status_id.inspect}"
    end

    changes = {
      step: canonical_sign_in_step_for(next_status_id),
      state: status_name_for(next_status_id),
    }
    changes[:completed_at] = now if next_status_id == status_id_for("COMPLETED")

    transition_cycle_to!(
      next_status_id,
      allowed_from: [status_id],
      changes: changes,
      now: now,
    )
  end

  def discard_sign_in!(now: Time.current)
    discard_cycle!(discard_at: now, purge_eligible_at: purge_eligible_at)
  end

  private

  def transition_sign_in_to!(next_status_name, step:, allowed_from:, now:, changes: {})
    transition_cycle_to!(
      status_id_for(next_status_name),
      allowed_from: status_ids_for(*allowed_from),
      changes: changes.merge(step: step, state: next_status_name),
      now: now,
    )
  end

  def normalize_sign_in_status_id(status)
    return status if status.is_a?(Integer)

    status_id_for(status)
  end

  def canonical_sign_in_step_for(status_id)
    {
      status_id_for("PRIMARY_PENDING") => "primary",
      status_id_for("MFA_PENDING") => "mfa",
      status_id_for("SESSION_LIMIT_PENDING") => "session_limit",
      status_id_for("GUARDRAIL_PENDING") => "guardrail",
      status_id_for("SESSION_ISSUANCE_PENDING") => "session_issuance",
      status_id_for("CHECKPOINT_PENDING") => "checkpoint",
      status_id_for("SELECTOR_PENDING") => "selector",
      status_id_for("DASHBOARD_PENDING") => "dashboard",
      status_id_for("RETURN_PENDING") => "return_to",
      status_id_for("COMPLETED") => "completed",
      status_id_for("FAILED") => "failed",
    }.fetch(status_id)
  end
end
