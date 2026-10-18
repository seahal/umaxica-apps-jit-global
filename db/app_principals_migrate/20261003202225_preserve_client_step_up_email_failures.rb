# frozen_string_literal: true

class PreserveClientStepUpEmailFailures < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!
  public

  def change
    add_column :client_emails, :step_up_otp_failures, :integer, default: 0, null: false
    add_column :client_emails, :step_up_otp_locked_until, :datetime
    add_column :client_emails, :step_up_otp_last_issued_at, :datetime
    add_check_constraint :client_emails, "step_up_otp_failures >= 0",
                         name: "client_email_step_up_failures_nonnegative", validate: false
    validate_check_constraint :client_emails, name: "client_email_step_up_failures_nonnegative"
  end
end
