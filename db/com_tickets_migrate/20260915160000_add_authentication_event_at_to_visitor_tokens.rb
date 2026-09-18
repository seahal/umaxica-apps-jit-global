# frozen_string_literal: true

class AddAuthenticationEventAtToVisitorTokens < ActiveRecord::Migration[8.2]
  def change
    add_column(:visitor_tokens, :authentication_event_at, :datetime)
  end
end
