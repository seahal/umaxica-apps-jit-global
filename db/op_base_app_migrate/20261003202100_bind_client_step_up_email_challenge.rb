# frozen_string_literal: true

class BindClientStepUpEmailChallenge < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!
  public

  def change
    add_column :client_step_up_sessions, :email_credential_ref, :string
    add_column :client_step_up_sessions, :email_code_digest, :string, limit: 64
    add_column :client_step_up_sessions, :email_code_generation, :integer, default: 0, null: false
    add_column :client_step_up_sessions, :email_code_issued_at, :datetime
    add_column :client_step_up_sessions, :email_code_expires_at, :datetime
    add_column :client_step_up_sessions, :email_code_consumed_at, :datetime
    add_column :client_step_up_sessions, :email_delivery_state, :string
    add_check_constraint :client_step_up_sessions, <<~SQL.squish,
      (
        email_code_generation = 0 AND email_credential_ref IS NULL AND email_code_digest IS NULL AND
        email_code_issued_at IS NULL AND email_code_expires_at IS NULL AND
        email_code_consumed_at IS NULL AND email_delivery_state IS NULL
      ) OR (
        email_code_generation > 0 AND email_credential_ref IS NOT NULL AND length(email_credential_ref) > 0 AND
        email_code_digest IS NOT NULL AND email_code_digest ~ '^[0-9a-f]{64}$' AND
        email_code_issued_at IS NOT NULL AND email_code_expires_at IS NOT NULL AND
        email_code_expires_at > email_code_issued_at AND
        email_code_expires_at <= email_code_issued_at + interval '10 minutes' AND
        email_delivery_state IS NOT NULL AND email_delivery_state IN ('pending', 'delivered', 'failed') AND
        (email_code_consumed_at IS NULL OR (
          email_delivery_state = 'delivered' AND email_code_consumed_at >= email_code_issued_at AND
          email_code_consumed_at < email_code_expires_at
        ))
      )
    SQL
                         name: "client_step_up_email_generation_valid", validate: false
    validate_check_constraint :client_step_up_sessions, name: "client_step_up_email_generation_valid"
  end
end
