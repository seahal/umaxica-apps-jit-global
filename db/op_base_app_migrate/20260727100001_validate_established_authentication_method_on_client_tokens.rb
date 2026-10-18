# frozen_string_literal: true

class ValidateEstablishedAuthenticationMethodOnClientTokens < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint(:client_tokens, name: "chk_client_tokens_established_authentication_method")
  end
end
