# frozen_string_literal: true

class AddEstablishedAuthenticationMethodToClientTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  METHODS = %w(email telephone secret passkey totp google apple).freeze

  def change
    add_column(:client_tokens, :established_authentication_method, :string)

    add_index(
      :client_tokens,
      :established_authentication_method,
      algorithm: :concurrently,
    )

    add_check_constraint(
      :client_tokens,
      "established_authentication_method IS NULL OR established_authentication_method IN (" \
      "#{METHODS.map { |m| "'#{m}'" }.join(", ")})",
      name: "chk_client_tokens_established_authentication_method",
      validate: false,
    )
  end
end
