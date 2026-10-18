# frozen_string_literal: true
class DropLegacyCompromisedAtFromSymbol < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      remove_index :customer_tokens, :compromised_at, if_exists: true
      remove_column :customer_tokens, :compromised_at, :datetime, if_exists: true
    end
  end
end
