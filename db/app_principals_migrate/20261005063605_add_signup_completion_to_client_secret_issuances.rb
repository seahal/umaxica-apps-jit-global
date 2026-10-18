# frozen_string_literal: true

class AddSignupCompletionToClientSecretIssuances < ActiveRecord::Migration[8.2]
  def change
    add_column(:client_secret_issuances, :signup_completed_at, :datetime)
  end
end
