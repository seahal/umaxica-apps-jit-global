# typed: false
# frozen_string_literal: true

class CreateUserOidcConnections < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    create_table :user_oidc_connections do |t|
      t.string :public_id, limit: 21, null: false
      t.bigint :user_id, null: false
      t.string :client_id, limit: 64, null: false
      t.string :scope
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_column :user_tokens, :oidc_connection_id, :bigint
    add_column :user_tokens, :oidc_client_id, :string, limit: 64
    add_column :user_tokens, :oidc_scope, :string

    add_index :user_oidc_connections, :public_id, unique: true, algorithm: :concurrently
    add_index :user_oidc_connections, %i(user_id client_id), unique: true, algorithm: :concurrently
    add_index :user_oidc_connections, :user_id, algorithm: :concurrently
    add_index :user_tokens, :oidc_connection_id, algorithm: :concurrently
    add_index :user_tokens, %i(user_id oidc_client_id), algorithm: :concurrently
  end
end
