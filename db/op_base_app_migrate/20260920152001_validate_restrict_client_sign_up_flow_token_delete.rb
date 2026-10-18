# frozen_string_literal: true

class ValidateRestrictClientSignUpFlowTokenDelete < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(:client_sign_up_flows, :client_tokens)
  end
end
