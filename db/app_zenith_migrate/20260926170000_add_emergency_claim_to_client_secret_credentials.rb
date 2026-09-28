# typed: false
# frozen_string_literal: true

# Durable exclusion for Emergency Secret Credential sign-in: a verified credential is claimed by one
# operation before any session can be created. See
# adr/emergency-secret-credential-commit-acknowledgement.md.
class AddEmergencyClaimToClientSecretCredentials < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column(:client_secret_credentials, :claim_operation_id, :uuid)
    add_column(:client_secret_credentials, :claimed_at, :datetime)
    add_index(:client_secret_credentials, :claim_operation_id, unique: true, algorithm: :concurrently)
  end
end
