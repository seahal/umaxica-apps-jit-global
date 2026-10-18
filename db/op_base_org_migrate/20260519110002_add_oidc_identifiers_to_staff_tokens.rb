# typed: false
# frozen_string_literal: true

class AddOidcIdentifiersToStaffTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column :staff_tokens, :oidc_sid, :uuid
    add_column :staff_tokens, :oidc_jti, :uuid

    change_column_default :staff_tokens, :oidc_sid, from: nil, to: -> { "gen_random_uuid()" }
    change_column_default :staff_tokens, :oidc_jti, from: nil, to: -> { "gen_random_uuid()" }

    add_index :staff_tokens, :oidc_sid, algorithm: :concurrently
    add_index :staff_tokens, :oidc_jti, algorithm: :concurrently
  end
end
