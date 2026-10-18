# typed: false
# frozen_string_literal: true

class CreateVisitorSecretCredentialCeremonyTransactions < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    create_table :visitor_secret_credential_ceremony_transactions, if_not_exists: true do |t|
      t.string :transaction_id, null: false
      t.string :surface, null: false
      t.string :actor_ref, null: false
      t.string :session_ref, null: false
      t.string :operation, null: false
      t.string :status, null: false, default: "pending"
      t.string :grant_jti, null: false
      t.string :result_jti
      t.string :credential_candidate_ref
      t.string :credential_candidate_digest
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.bigint :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :visitor_secret_credential_ceremony_transactions, :transaction_id, unique: true,
                                                                                    algorithm: :concurrently,
                                                                                    if_not_exists: true
    add_index :visitor_secret_credential_ceremony_transactions, :grant_jti, unique: true,
                                                                               algorithm: :concurrently,
                                                                               if_not_exists: true
    add_index :visitor_secret_credential_ceremony_transactions, :result_jti, unique: true,
                                                                                where: "result_jti IS NOT NULL",
                                                                                algorithm: :concurrently,
                                                                                if_not_exists: true
    add_index :visitor_secret_credential_ceremony_transactions, :expires_at, algorithm: :concurrently,
                                                                             if_not_exists: true
    add_index :visitor_secret_credential_ceremony_transactions, %i(actor_ref session_ref),
              algorithm: :concurrently,
              if_not_exists: true
  end
end
