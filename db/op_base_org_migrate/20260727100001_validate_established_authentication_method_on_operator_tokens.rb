# frozen_string_literal: true

class ValidateEstablishedAuthenticationMethodOnOperatorTokens < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint(:operator_tokens, name: "chk_operator_tokens_established_authentication_method")
  end
end
