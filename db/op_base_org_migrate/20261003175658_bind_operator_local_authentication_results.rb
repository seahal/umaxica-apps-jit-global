# frozen_string_literal: true

# Additive transport evidence; existing flows remain ineligible until evidence is recorded.
class BindOperatorLocalAuthenticationResults < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  public

  def change
    %i(operator_sign_in_flows operator_sign_up_flows).each do |table|
      add_column(table, :result_digest, :string, limit: 64)
      add_column(table, :result_generation, :integer, null: false, default: 0)
      add_column(table, :result_expires_at, :datetime)
      add_column(table, :base_finalized_at, :datetime)
      add_column(table, :authentication_method, :string)
      add_column(table, :authentication_event_at, :datetime)
      add_index(table, :result_digest, unique: true, algorithm: :concurrently)
      add_check_constraint(table, "result_generation >= 0", name: "#{table}_result_generation_valid", validate: false)
      add_check_constraint(
        table,
        "(authentication_method IS NULL AND authentication_event_at IS NULL) OR " \
        "(authentication_method IN ('email','telephone','secret','passkey','totp','google','apple','entra') " \
        "AND authentication_event_at IS NOT NULL AND principal_id IS NOT NULL)",
        name: "#{table}_authentication_evidence_valid", validate: false,
      )
      add_check_constraint(
        table,
        "(result_digest IS NULL AND result_expires_at IS NULL AND result_generation = 0) OR " \
        "(length(result_digest) = 64 AND result_expires_at IS NOT NULL AND result_generation > 0 " \
        "AND authentication_event_at IS NOT NULL)",
        name: "#{table}_result_delivery_valid", validate: false,
      )
      add_check_constraint(
        table,
        "base_finalized_at IS NULL OR (token_id IS NOT NULL AND result_digest IS NOT NULL)",
        name: "#{table}_base_finalization_valid", validate: false,
      )
      validate_check_constraint(table, name: "#{table}_result_generation_valid")
      validate_check_constraint(table, name: "#{table}_authentication_evidence_valid")
      validate_check_constraint(table, name: "#{table}_result_delivery_valid")
      validate_check_constraint(table, name: "#{table}_base_finalization_valid")
    end

    bind_ceremony_to_local_flows
  end

  private

  def bind_ceremony_to_local_flows
    add_column(:operator_auth_ceremony_sessions, :local_sign_in_flow_ref, :string)
    add_column(:operator_auth_ceremony_sessions, :local_sign_up_flow_ref, :string)
    add_foreign_key(
      :operator_auth_ceremony_sessions, :operator_sign_in_flows,
      column: :local_sign_in_flow_ref, primary_key: :public_id, on_delete: :restrict, validate: false,
    )
    add_foreign_key(
      :operator_auth_ceremony_sessions, :operator_sign_up_flows,
      column: :local_sign_up_flow_ref, primary_key: :public_id, on_delete: :restrict, validate: false,
    )
    add_check_constraint(
      :operator_auth_ceremony_sessions,
      "num_nonnulls(authorization_transaction_ref, local_sign_in_flow_ref, local_sign_up_flow_ref) <= 1",
      name: "operator_auth_ceremony_purpose_exclusive", validate: false,
    )
    validate_foreign_key(:operator_auth_ceremony_sessions, :operator_sign_in_flows)
    validate_foreign_key(:operator_auth_ceremony_sessions, :operator_sign_up_flows)
    validate_check_constraint(:operator_auth_ceremony_sessions, name: "operator_auth_ceremony_purpose_exclusive")
  end
end
