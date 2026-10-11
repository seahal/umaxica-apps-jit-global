# frozen_string_literal: true

require_relative "20261007182157_preserve_visitor_sign_up_otp_proof"
require_relative "20261007183050_enforce_finite_visitor_sign_up_otp_proof_times"
require_relative "20261007193041_preserve_visitor_credential_registration_otp_proof"

# P3d retires only the named source-proof DDL after all writers use concrete ceremonies.
# Apply on the approved disposable fleet; retained-data cutover needs writer quiescence.
class RetireVisitorIdentifierOtpContexts < ActiveRecord::Migration[8.2]
  TABLES = %i(visitor_emails visitor_telephones).freeze

  def up
    safety_assured do
      TABLES.each do |table|
        # This transactional DDL takes a table lock before inspection, preventing late writers.
        remove_check_constraint(table, name: "#{table}_sign_up_otp_context_shape")
      end
    end
    TABLES.each do |table|
      # Refuse to discard proof facts: ambiguous legacy rows need independent reconciliation.
      count = connection.select_value(
        "SELECT COUNT(*) FROM #{connection.quote_table_name(table)} " \
        "WHERE sign_up_otp_context IS NOT NULL OR credential_registration_otp_context IS NOT NULL",
      ).to_i
      raise ActiveRecord::MigrationError, "#{table} retains legacy proof contexts" unless count.zero?
    end

    # The scoped exception retires exactly the previously approved proof objects.
    safety_assured do
      TABLES.each do |table|
        execute("DROP TRIGGER #{table}_sign_up_otp_proof_trigger ON #{table}")
        execute("DROP TRIGGER #{table}_credential_registration_otp_proof_trigger ON #{table}")
        remove_check_constraint(table, name: "#{table}_sign_up_otp_times_finite")
        remove_check_constraint(table, name: "#{table}_credential_registration_otp_shape")
        remove_column(table, :sign_up_otp_context, :jsonb)
        remove_column(table, :credential_registration_otp_context, :jsonb)
      end
      execute("DROP FUNCTION enforce_visitor_sign_up_otp_proof()")
      execute("DROP FUNCTION enforce_visitor_credential_registration_otp_proof()")
    end
  end

  def down
    TABLES.each do |table|
      add_column(table, :sign_up_otp_context, :jsonb)
      add_column(table, :credential_registration_otp_context, :jsonb)
    end
    # Reuse the immutable historical DDL definitions, without altering migration history.
    # Restored columns are newly added and NULL for every row; validation admits only that state.
    # This reverse rehearsal is scoped to the approved disposable fleet, not a live rollback.
    safety_assured do
      PreserveVisitorSignUpOtpProof.new.up
      EnforceFiniteVisitorSignUpOtpProofTimes.new.up
      PreserveVisitorCredentialRegistrationOtpProof.new.up
    end
  end
end
