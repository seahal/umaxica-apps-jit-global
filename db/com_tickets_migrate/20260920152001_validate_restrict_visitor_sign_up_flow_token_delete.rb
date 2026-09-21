# frozen_string_literal: true

class ValidateRestrictVisitorSignUpFlowTokenDelete < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(:visitor_sign_up_flows, :visitor_tokens)
  end
end
