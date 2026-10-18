# frozen_string_literal: true

class AddLastStepUpPhishingResistantToOperatorTokens < ActiveRecord::Migration[8.2]
  def change
    add_column(:operator_tokens, :last_step_up_phishing_resistant, :boolean, null: false, default: false)
  end
end
