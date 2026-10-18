# frozen_string_literal: true

class AddLastStepUpPhishingResistantToClientTokens < ActiveRecord::Migration[8.2]
  def change
    add_column(:client_tokens, :last_step_up_phishing_resistant, :boolean, null: false, default: false)
  end
end
