# typed: false
# frozen_string_literal: true

class ValidateRpPalmAppLocalSchema < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  CHECKS = %w(
    chk_rp_palm_app_identity_bindings_cell
    chk_rp_palm_app_op_session_bindings_cell
    chk_rp_palm_app_sessions_shape
    chk_rp_palm_app_callback_states_cell
    chk_rp_palm_app_refresh_attempts_shape
    chk_rp_palm_app_event_receipts_cell
  ).freeze

  FOREIGN_KEYS = [
    [:rp_identity_bindings, "fk_rp_palm_app_identity_bindings_principal"],
    [:rp_op_session_bindings, "fk_rp_palm_app_op_session_bindings_identity"],
    [:rp_sessions, "fk_rp_palm_app_sessions_op_binding"],
    [:rp_refresh_attempts, "fk_rp_palm_app_refresh_attempts_session"],
    [:rp_event_receipts, "fk_rp_palm_app_event_receipts_op_binding"],
  ].freeze

  def up
    CHECKS.each { |name| validate_check_constraint(name_table(name), name:) }
    FOREIGN_KEYS.each { |table, name| validate_foreign_key(table, name:) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "R5 RP local constraints are forward-only"
  end

  private

  def name_table(name)
    case name
    when /identity_bindings_cell/ then :rp_identity_bindings
    when /op_session_bindings_cell/ then :rp_op_session_bindings
    when /sessions_shape/ then :rp_sessions
    when /callback_states_cell/ then :rp_callback_states
    when /refresh_attempts_shape/ then :rp_refresh_attempts
    when /event_receipts_cell/ then :rp_event_receipts
    else raise ArgumentError, "unknown R5 RP constraint: #{name.inspect}"
    end
  end
end
