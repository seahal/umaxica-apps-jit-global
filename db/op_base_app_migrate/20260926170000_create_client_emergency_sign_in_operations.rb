# typed: false
# frozen_string_literal: true

# Same-transaction proof that an Emergency Secret Credential sign-in committed its app session.
# The row is written in the app_ticket transaction that creates the ClientToken; the credential in
# app_zenith is consumed only after this row is observed. See
# adr/emergency-secret-credential-commit-acknowledgement.md.
class CreateClientEmergencySignInOperations < ActiveRecord::Migration[8.2]
  def change
    create_table(:client_emergency_sign_in_operations) do |t|
      t.uuid(:operation_id, null: false)
      t.string(:credential_public_id, limit: 21, null: false)
      t.references(:client_token, null: false, foreign_key: true, index: { unique: true })

      t.timestamps
    end

    add_index(:client_emergency_sign_in_operations, :operation_id, unique: true)
    # One credential can prove at most one session, whatever operation ids a caller presents.
    add_index(:client_emergency_sign_in_operations, :credential_public_id, unique: true)
  end
end
