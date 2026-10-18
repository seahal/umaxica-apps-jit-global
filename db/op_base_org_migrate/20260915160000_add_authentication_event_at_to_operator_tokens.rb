# frozen_string_literal: true

class AddAuthenticationEventAtToOperatorTokens < ActiveRecord::Migration[8.2]
  def change
    add_column(:operator_tokens, :authentication_event_at, :datetime)
  end
end
