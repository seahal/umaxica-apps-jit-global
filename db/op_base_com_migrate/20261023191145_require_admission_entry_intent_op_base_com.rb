# frozen_string_literal: true

# D-129/D-157/D-159: final intent values on empty tables; no NULL state and no backfill.
class RequireAdmissionEntryIntentOpBaseCom < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLE = :visitor_auth_admission_bindings
  CONSTRAINT = "visitor_admission_binding_entry_intent"
  AUTHENTICATION = %w(authentication_handoff invitation_handoff).freeze
  REVERIFICATION = %w(step_up_handoff reauthentication_handoff bootstrap_handoff
                      credential_registration_handoff credential_change_handoff).freeze

  public

  def up
    remove_check_constraint(TABLE, name: CONSTRAINT)
    safety_assured { change_column_null(TABLE, :entry_intent, false) }
    add_check_constraint(
      TABLE,
      "(purpose IN (#{AUTHENTICATION.map { |value| connection.quote(value) }.join(", ")}) " \
      "AND entry_intent IN ('sign_in', 'sign_up')) OR " \
      "(purpose IN (#{REVERIFICATION.map { |value| connection.quote(value) }.join(", ")}) " \
      "AND entry_intent = 'not_applicable')",
      name: CONSTRAINT, validate: false,
    )
    validate_check_constraint(TABLE, name: CONSTRAINT)
  end

  def down
    remove_check_constraint(TABLE, name: CONSTRAINT)
    change_column_null(TABLE, :entry_intent, true)
    add_check_constraint(
      TABLE, "entry_intent IS NULL OR entry_intent IN ('sign_in', 'sign_up')",
      name: CONSTRAINT, validate: false,
    )
    validate_check_constraint(TABLE, name: CONSTRAINT)
  end
end
