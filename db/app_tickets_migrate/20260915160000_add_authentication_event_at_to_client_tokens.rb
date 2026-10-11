# frozen_string_literal: true

class AddAuthenticationEventAtToClientTokens < ActiveRecord::Migration[8.2]
  def change
    add_column(:client_tokens, :authentication_event_at, :datetime)
  end
end
