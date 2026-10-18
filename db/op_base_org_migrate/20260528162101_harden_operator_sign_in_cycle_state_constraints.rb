# frozen_string_literal: true

class HardenOperatorSignInCycleStateConstraints < ActiveRecord::Migration[8.2]
  STATE_CONSTRAINT = "chk_operator_sign_in_cycles_status_state"
  STEP_CONSTRAINT = "chk_operator_sign_in_cycles_status_step"

  def up
    add_constraint_unless_exists(:operator_sign_in_cycles, status_state_sql, STATE_CONSTRAINT)
    add_constraint_unless_exists(:operator_sign_in_cycles, status_step_sql, STEP_CONSTRAINT)
  end

  def down
    remove_check_constraint(:operator_sign_in_cycles, name: STATE_CONSTRAINT, if_exists: true)
    remove_check_constraint(:operator_sign_in_cycles, name: STEP_CONSTRAINT, if_exists: true)
  end

  private

  def add_constraint_unless_exists(table, expression, name)
    return if check_constraint_exists?(table, name: name)

    add_check_constraint(table, expression, name: name, validate: false)
  end

  def status_state_sql
    "state = CASE status_id WHEN 10 THEN 'PRIMARY_PENDING' WHEN 20 THEN 'MFA_PENDING' " \
      "WHEN 30 THEN 'SESSION_LIMIT_PENDING' WHEN 40 THEN 'GUARDRAIL_PENDING' " \
      "WHEN 50 THEN 'SESSION_ISSUANCE_PENDING' WHEN 60 THEN 'CHECKPOINT_PENDING' " \
      "WHEN 65 THEN 'SELECTOR_PENDING' WHEN 70 THEN 'DASHBOARD_PENDING' " \
      "WHEN 80 THEN 'RETURN_PENDING' WHEN 100 THEN 'COMPLETED' WHEN 900 THEN 'FAILED' END"
  end

  def status_step_sql
    "step = CASE status_id WHEN 10 THEN 'primary' WHEN 20 THEN 'mfa' " \
      "WHEN 30 THEN 'session_limit' WHEN 40 THEN 'guardrail' WHEN 50 THEN 'session_issuance' " \
      "WHEN 60 THEN 'checkpoint' WHEN 65 THEN 'selector' WHEN 70 THEN 'dashboard' " \
      "WHEN 80 THEN 'return_to' WHEN 100 THEN 'completed' WHEN 900 THEN 'failed' END"
  end
end
