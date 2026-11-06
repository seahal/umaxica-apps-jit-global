# frozen_string_literal: true

class ConstrainClientStepUpAuditCodes < ActiveRecord::Migration[8.2]
  def change
    add_check_constraint(
      :client_step_up_context_transitions,
      "reason_code IN ('requested', 'dispatch_started', 'completed', 'user_cancelled', 'expired', 'binding_mismatch', 'expectation_mismatch', 'policy_refused', 'unsatisfiable_class', 'op_error', 'generation_superseded', 'session_invalid', 'exchange_timeout', 'dispatch_deadline_passed', 'foreign_browser', 'state_mismatch', 'duplicate_callback')",
      name: "chk_client_step_up_transition_reason",
      validate: false,
    )
    add_check_constraint(
      :client_step_up_audit_outboxes,
      "reason_code IN ('requested', 'dispatch_started', 'completed', 'user_cancelled', 'expired', 'binding_mismatch', 'expectation_mismatch', 'policy_refused', 'unsatisfiable_class', 'op_error', 'generation_superseded', 'session_invalid', 'exchange_timeout', 'dispatch_deadline_passed', 'foreign_browser', 'state_mismatch', 'duplicate_callback')",
      name: "chk_client_step_up_audit_reason_codes",
      validate: false,
    )
    add_check_constraint(
      :client_step_up_audit_outboxes,
      <<~SQL.squish,
        (event_type <> 'step_up.failed' OR COALESCE(payload ->> 'failure_code', '') IN ('binding_mismatch', 'expectation_mismatch', 'policy_refused', 'unsatisfiable_class')) AND
        (event_type NOT IN ('step_up.refused', 'step_up.indeterminate') OR COALESCE(payload ->> 'failure_code', '') IN ('op_error', 'generation_superseded', 'session_invalid', 'exchange_timeout', 'dispatch_deadline_passed')) AND
        (event_type <> 'step_up.attempt_rejected' OR COALESCE(payload ->> 'rejection_code', '') IN ('foreign_browser', 'state_mismatch', 'duplicate_callback'))
      SQL
      name: "chk_client_step_up_audit_payload_codes",
      validate: false,
    )
    add_check_constraint(
      :client_step_up_audit_outbox_attempts,
      "failure_code IN ('none', 'chronicle_unavailable', 'retention_policy_missing', 'event_identity_conflict', 'chronicle_record_invalid', 'delivery_failed')",
      name: "chk_client_step_up_attempt_failure_codes",
      validate: false,
    )
    add_check_constraint(
      :client_step_up_audit_outbox_attempts,
      "outcome <> 'delivered' OR failure_code = 'none'",
      name: "chk_client_step_up_delivered_failure_none",
      validate: false,
    )
  end
end
