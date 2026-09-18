# typed: false
# frozen_string_literal: true

class CreateVisitorRpSessionsAndBindAuthorizationCodes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    create_table :visitor_rp_sessions do |t|
      t.references :visitor_token, null: false, foreign_key: { on_delete: :cascade }
      t.string :public_id, null: false, limit: 21
      t.string :oidc_client_id, null: false, limit: 64
      t.text :oidc_scope
      t.string :oidc_jti
      t.string :refresh_token_digest
      t.string :previous_refresh_token_digest
      t.datetime :refresh_token_expires_at
      t.datetime :refresh_token_rotated_at
      t.string :dpop_jkt
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.string :last_logout_status
      t.datetime :last_logout_attempted_at
      t.datetime :logged_out_at
      t.timestamps
    end

    add_index :visitor_rp_sessions, :public_id, unique: true
    add_index :visitor_rp_sessions,
              %i[visitor_token_id oidc_client_id],
              unique: true,
              where: "revoked_at IS NULL",
              name: "idx_active_visitor_rp_session_per_rp"
    add_index :visitor_rp_sessions, :refresh_token_digest, unique: true, where: "refresh_token_digest IS NOT NULL"
    add_index :visitor_rp_sessions, :oidc_client_id
    add_index :visitor_rp_sessions, :revoked_at


  end
end
