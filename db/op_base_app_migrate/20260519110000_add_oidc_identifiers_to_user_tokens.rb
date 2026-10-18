# typed: false
# frozen_string_literal: true

class AddOidcIdentifiersToUserTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column :user_tokens, :oidc_sid, :uuid
    add_column :user_tokens, :oidc_jti, :uuid

    change_column_default :user_tokens, :oidc_sid, from: nil, to: -> { "gen_random_uuid()" }
    change_column_default :user_tokens, :oidc_jti, from: nil, to: -> { "gen_random_uuid()" }

    add_index :user_tokens, :oidc_sid, algorithm: :concurrently, if_not_exists: true
    add_index :user_tokens, :oidc_jti, algorithm: :concurrently, if_not_exists: true
  end
end
