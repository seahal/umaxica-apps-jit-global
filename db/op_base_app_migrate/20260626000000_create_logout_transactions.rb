# typed: false
# frozen_string_literal: true

class CreateLogoutTransactions < ActiveRecord::Migration[8.2]
  def change
    create_table :logout_transactions do |t|
      t.string :public_id, null: false
      t.binary :token_digest, null: false
      t.string :issuer, null: false
      t.string :audience, null: false
      t.string :purpose, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.datetime :revoked_at
      t.datetime :failed_at
      t.string :failure_code
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :logout_transactions, :public_id, unique: true
    add_index :logout_transactions, :token_digest, unique: true
    add_index :logout_transactions, %i(issuer audience purpose)
    add_index :logout_transactions, :expires_at
  end
end
