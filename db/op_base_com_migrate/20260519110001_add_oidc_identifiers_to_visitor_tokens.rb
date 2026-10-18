# typed: false
# frozen_string_literal: true

class AddOidcIdentifiersToVisitorTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column :visitor_tokens, :oidc_sid, :uuid
    add_column :visitor_tokens, :oidc_jti, :uuid

    change_column_default :visitor_tokens, :oidc_sid, from: nil, to: -> { "gen_random_uuid()" }
    change_column_default :visitor_tokens, :oidc_jti, from: nil, to: -> { "gen_random_uuid()" }

    add_index :visitor_tokens, :oidc_sid, algorithm: :concurrently
    add_index :visitor_tokens, :oidc_jti, algorithm: :concurrently
  end
end
