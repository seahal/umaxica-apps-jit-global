# frozen_string_literal: true

class AddAuthenticationFactsToClientSecretCredentials < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!
  def change
    add_column :client_secret_credentials, :claim_sign_in_flow_ref, :string, limit: 21
    add_column :client_secret_credentials, :claim_ceremony_session_id, :bigint
    add_column :client_secret_credentials, :consumed_at, :datetime
    add_index :client_secret_credentials, :claim_sign_in_flow_ref, unique: true, algorithm: :concurrently
    add_check_constraint :client_secret_credentials,
                         "(claimed_at IS NULL) = (claim_sign_in_flow_ref IS NULL) AND " \
                         "(claimed_at IS NULL) = (claim_ceremony_session_id IS NULL)",
                         name: "client_secret_claim_binding", validate: false
    add_check_constraint :client_secret_credentials,
                         "consumed_at IS NULL OR (claimed_at IS NOT NULL AND consumed_at >= claimed_at " \
                         "AND discard_at <= consumed_at)", name: "client_secret_consumption", validate: false
    validate_check_constraint :client_secret_credentials, name: "client_secret_claim_binding"
    validate_check_constraint :client_secret_credentials, name: "client_secret_consumption"
  end
end
