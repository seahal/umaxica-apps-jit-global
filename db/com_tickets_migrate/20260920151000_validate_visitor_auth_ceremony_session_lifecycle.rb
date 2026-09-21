# typed: false
# frozen_string_literal: true

class ValidateVisitorAuthCeremonySessionLifecycle < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(
      :visitor_auth_ceremony_sessions,
      name: "visitor_auth_ceremony_sessions_one_terminal_timestamp",
    )
    validate_check_constraint(
      :visitor_auth_ceremony_sessions,
      name: "visitor_auth_ceremony_sessions_admission_binding",
    )
  end
end
