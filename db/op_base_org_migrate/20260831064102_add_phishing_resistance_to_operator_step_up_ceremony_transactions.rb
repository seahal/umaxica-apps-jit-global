# frozen_string_literal: true

class AddPhishingResistanceToOperatorStepUpCeremonyTransactions < ActiveRecord::Migration[8.2]
  def change
    add_column(:operator_step_up_ceremony_transactions, :phishing_resistant_required, :boolean, null: false, default: false)
    add_column(:operator_step_up_ceremony_transactions, :phishing_resistant, :boolean, null: false, default: false)
  end
end
