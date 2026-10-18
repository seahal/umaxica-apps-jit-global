# frozen_string_literal: true

# Preserve the verified session capability context across the Auth-to-Base handoff.
class PreserveVisitorLocalAuthenticationContext < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  public

  def change
    add_column(:visitor_sign_in_flows, :authentication_context, :string)
    add_check_constraint(
      :visitor_sign_in_flows,
      "authentication_context IS NULL OR authentication_context IN ('normal', 'emergency')",
      name: "visitor_local_authentication_context_valid", validate: false,
    )
    validate_check_constraint(:visitor_sign_in_flows, name: "visitor_local_authentication_context_valid")

    %i(visitor_sign_in_flows visitor_sign_up_flows).each do |table|
      # Explicit non-null predicates prevent SQL UNKNOWN from accepting incomplete evidence.
      add_check_constraint(
        table,
        "authentication_event_at IS NULL OR authentication_method IS NOT NULL",
        name: "#{table}_evidence_complete", validate: false,
      )
      add_check_constraint(
        table,
        "result_generation = 0 OR (result_digest IS NOT NULL AND result_expires_at IS NOT NULL " \
        "AND authentication_event_at IS NOT NULL)",
        name: "#{table}_result_complete", validate: false,
      )
      validate_check_constraint(table, name: "#{table}_evidence_complete")
      validate_check_constraint(table, name: "#{table}_result_complete")
    end
  end
end
