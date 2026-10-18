# typed: false
# frozen_string_literal: true

class CreateVisitorOidcConnections < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    create_table :visitor_oidc_connections do |t|
      t.string :public_id, limit: 21, null: false
      t.bigint :visitor_id, null: false
      t.string :client_id, limit: 64, null: false
      t.string :scope
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_column :visitor_tokens, :oidc_connection_id, :bigint
    add_column :visitor_tokens, :oidc_client_id, :string, limit: 64
    add_column :visitor_tokens, :oidc_scope, :string

    add_index :visitor_oidc_connections, :public_id, unique: true, algorithm: :concurrently
    add_index :visitor_oidc_connections, %i(visitor_id client_id), unique: true, algorithm: :concurrently
    add_index :visitor_oidc_connections, :visitor_id, algorithm: :concurrently
    add_index :visitor_tokens, :oidc_connection_id, algorithm: :concurrently
    add_index :visitor_tokens, %i(visitor_id oidc_client_id), algorithm: :concurrently
  end
end
