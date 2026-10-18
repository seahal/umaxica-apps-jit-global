# frozen_string_literal: true

class CreateVisitorAuthorizationCodes < ActiveRecord::Migration[8.2]
  def change
    create_table :visitor_authorization_codes do |t|
      t.bigint :visitor_id, null: false
      t.string :client_id, limit: 64, null: false
      t.string :code, limit: 64, null: false
      t.text :redirect_uri, null: false
      t.string :code_challenge, null: false
      t.string :code_challenge_method, limit: 8, null: false, default: "S256"
      t.string :scope
      t.string :state
      t.string :nonce
      t.string :auth_method
      t.string :acr
      t.datetime :consumed_at
      t.datetime :discarded_at, null: false, default: "infinity"
      t.datetime :purged_at, null: false, default: "infinity"

      t.timestamps

      t.index :code, unique: true
      t.index :visitor_id
      t.check_constraint "discarded_at <= purged_at", name: "chk_visitor_authorization_codes_retention_order"
    end
  end
end
