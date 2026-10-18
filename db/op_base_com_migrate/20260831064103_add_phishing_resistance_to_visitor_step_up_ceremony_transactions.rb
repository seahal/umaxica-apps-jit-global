# frozen_string_literal: true

class AddPhishingResistanceToVisitorStepUpCeremonyTransactions < ActiveRecord::Migration[8.2]
  def change
    add_column(:visitor_step_up_ceremony_transactions, :phishing_resistant_required, :boolean, null: false, default: false)
    add_column(:visitor_step_up_ceremony_transactions, :phishing_resistant, :boolean, null: false, default: false)
  end
end
