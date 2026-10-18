# frozen_string_literal: true

# Rollback requires draining candidates with an unconfirmed code and admissions using new purposes.
# Existing unbound rows remain historical; the new application path requires the explicit FK.
class BindClientCredentialCeremoniesToBaseAuthority < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  public

  def change
    %i(client_passkey_ceremony_transactions client_totp_ceremony_transactions identity_totp_ceremony_candidates).each do |table|
      add_column(table, :step_up_ceremony_transaction_ref, :string)
      add_index(table, :step_up_ceremony_transaction_ref, algorithm: :concurrently)
      add_foreign_key(
        table, :client_step_up_ceremony_transactions,
        column: :step_up_ceremony_transaction_ref, primary_key: :transaction_id,
        on_delete: :restrict, validate: false,
      )
      validate_foreign_key(table, :client_step_up_ceremony_transactions)
    end

    change_column_null(:identity_totp_ceremony_candidates, :last_otp_at, true)
    add_check_constraint(
      :identity_totp_ceremony_candidates,
      "last_otp_at IS NOT NULL OR step_up_ceremony_transaction_ref IS NOT NULL",
      name: "totp_candidate_pending_authority", validate: false,
    )
    validate_check_constraint(:identity_totp_ceremony_candidates, name: "totp_candidate_pending_authority")

    old_purposes = "admission_purpose IS NULL OR admission_purpose IN ('local_sign_in','local_sign_up'," \
                   "'authentication_handoff','invitation_handoff','step_up_handoff','reauthentication_handoff')"
    new_purposes = "admission_purpose IS NULL OR admission_purpose IN ('local_sign_in','local_sign_up'," \
                   "'authentication_handoff','invitation_handoff','step_up_handoff','reauthentication_handoff'," \
                   "'bootstrap_handoff','credential_registration_handoff','credential_change_handoff')"
    remove_check_constraint(
      :client_auth_ceremony_sessions, old_purposes,
      name: "client_auth_admission_purpose_valid",
    )
    add_check_constraint(
      :client_auth_ceremony_sessions, new_purposes,
      name: "client_auth_admission_purpose_valid", validate: false,
    )
    validate_check_constraint(:client_auth_ceremony_sessions, name: "client_auth_admission_purpose_valid")
  end
end
