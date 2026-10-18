# typed: false
# frozen_string_literal: true

class CreateIdentityCeremonyCandidates < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    create_table :identity_social_ceremony_candidates, if_not_exists: true do |t|
      t.string :ref, null: false
      t.string :digest, null: false
      t.string :surface, null: false
      t.string :actor_ref, null: false
      t.string :session_ref, null: false
      t.string :transaction_id, null: false
      t.string :operation, null: false
      t.string :provider, null: false
      t.text :auth_hash, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.bigint :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :identity_social_ceremony_candidates, :ref, unique: true, algorithm: :concurrently,
                                                            if_not_exists: true
    add_index :identity_social_ceremony_candidates, :expires_at, algorithm: :concurrently, if_not_exists: true
    add_index :identity_social_ceremony_candidates, %i(actor_ref session_ref), algorithm: :concurrently,
                                                                                if_not_exists: true
    add_index :identity_social_ceremony_candidates, %i(transaction_id operation), algorithm: :concurrently,
                                                                                    if_not_exists: true

    create_table :identity_totp_ceremony_candidates, if_not_exists: true do |t|
      t.string :ref, null: false
      t.string :digest, null: false
      t.string :surface, null: false
      t.string :actor_ref, null: false
      t.string :session_ref, null: false
      t.text :private_key, null: false
      t.string :title
      t.datetime :last_otp_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.bigint :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :identity_totp_ceremony_candidates, :ref, unique: true, algorithm: :concurrently,
                                                          if_not_exists: true
    add_index :identity_totp_ceremony_candidates, :expires_at, algorithm: :concurrently, if_not_exists: true
    add_index :identity_totp_ceremony_candidates, %i(actor_ref session_ref), algorithm: :concurrently,
                                                                              if_not_exists: true

    create_table :identity_secret_credential_ceremony_candidates, if_not_exists: true do |t|
      t.string :ref, null: false
      t.string :digest, null: false
      t.string :surface, null: false
      t.string :actor_ref, null: false
      t.string :session_ref, null: false
      t.string :transaction_id, null: false
      t.string :operation, null: false
      t.text :password_digest, null: false
      t.string :name, null: false
      t.boolean :enabled, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.bigint :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :identity_secret_credential_ceremony_candidates, :ref, unique: true, algorithm: :concurrently,
                                                                       if_not_exists: true
    add_index :identity_secret_credential_ceremony_candidates, :expires_at, algorithm: :concurrently,
                                                                           if_not_exists: true
    add_index :identity_secret_credential_ceremony_candidates, %i(actor_ref session_ref),
              algorithm: :concurrently,
              if_not_exists: true
    add_index :identity_secret_credential_ceremony_candidates, %i(transaction_id operation),
              algorithm: :concurrently,
              if_not_exists: true
  end
end
