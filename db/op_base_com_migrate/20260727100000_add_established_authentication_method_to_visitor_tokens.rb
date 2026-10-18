# frozen_string_literal: true

class AddEstablishedAuthenticationMethodToVisitorTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  METHODS = %w(email telephone secret passkey).freeze

  def change
    add_column(:visitor_tokens, :established_authentication_method, :string)

    add_index(
      :visitor_tokens,
      :established_authentication_method,
      algorithm: :concurrently,
    )

    add_check_constraint(
      :visitor_tokens,
      "established_authentication_method IS NULL OR established_authentication_method IN (" \
      "#{METHODS.map { |m| "'#{m}'" }.join(", ")})",
      name: "chk_visitor_tokens_established_authentication_method",
      validate: false,
    )
  end
end
