# frozen_string_literal: true

class ValidateRpBaseAppStepUpAuditCodes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  REASON_CODE_CHECK = "reason_code IN ('requested', 'dispatch_started', 'completed', 'user_cancelled', 'expired', 'binding_mismatch', 'expectation_mismatch', 'policy_refused', 'unsatisfiable_class', 'op_error', 'generation_superseded', 'session_invalid', 'exchange_timeout', 'dispatch_deadline_passed', 'foreign_browser', 'state_mismatch', 'duplicate_callback')"
  PAYLOAD_CODE_CHECK = <<~SQL.squish
    (event_type <> 'step_up.failed' OR COALESCE(payload ->> 'failure_code', '') IN ('binding_mismatch', 'expectation_mismatch', 'policy_refused', 'unsatisfiable_class')) AND
    (event_type NOT IN ('step_up.refused', 'step_up.indeterminate') OR COALESCE(payload ->> 'failure_code', '') IN ('op_error', 'generation_superseded', 'session_invalid', 'exchange_timeout', 'dispatch_deadline_passed')) AND
    (event_type <> 'step_up.attempt_rejected' OR COALESCE(payload ->> 'rejection_code', '') IN ('foreign_browser', 'state_mismatch', 'duplicate_callback'))
  SQL
  ATTEMPT_FAILURE_CODE_CHECK = "failure_code IN ('none', 'chronicle_unavailable', 'retention_policy_missing', 'event_identity_conflict', 'chronicle_record_invalid', 'delivery_failed')"
  DELIVERED_FAILURE_CODE_CHECK = "outcome <> 'delivered' OR failure_code = 'none'"
  CHECKS = [
    [:rp_step_up_state_transitions, "chk_rp_step_up_transition_reason", REASON_CODE_CHECK],
    [:rp_step_up_audit_outboxes, "chk_rp_step_up_audit_reason_codes", REASON_CODE_CHECK],
    [:rp_step_up_audit_outboxes, "chk_rp_step_up_audit_payload_codes", PAYLOAD_CODE_CHECK],
    [:rp_step_up_audit_outbox_attempts, "chk_rp_step_up_attempt_failure_codes", ATTEMPT_FAILURE_CODE_CHECK],
    [:rp_step_up_audit_outbox_attempts, "chk_rp_step_up_delivered_failure_none", DELIVERED_FAILURE_CODE_CHECK],
  ].freeze

  def up
    CHECKS.each { |table, name, _expression| validate_check_constraint(table, name:) }
  end

  def down
    CHECKS.each do |table, name, expression|
      remove_check_constraint(table, name:)
      add_check_constraint(table, expression, name:, validate: false)
    end
  end
end
