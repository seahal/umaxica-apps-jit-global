# frozen_string_literal: true

class ValidateEstablishedAuthenticationMethodOnVisitorTokens < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint(:visitor_tokens, name: "chk_visitor_tokens_established_authentication_method")
  end
end
