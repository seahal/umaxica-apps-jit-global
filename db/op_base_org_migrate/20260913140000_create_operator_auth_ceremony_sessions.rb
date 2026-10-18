# typed: false
# frozen_string_literal: true

class CreateOperatorAuthCeremonySessions < ActiveRecord::Migration[8.1]
  def change
    create_table :operator_auth_ceremony_sessions do |t|
      t.string :sid_digest, null: false, limit: 64
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.datetime :rotated_at
      t.string :previous_sid_digest, limit: 64
      t.timestamps
    end

    add_index :operator_auth_ceremony_sessions, :sid_digest, unique: true
    add_index :operator_auth_ceremony_sessions, :expires_at
    add_index :operator_auth_ceremony_sessions, :revoked_at
  end
end
