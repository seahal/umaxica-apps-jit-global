# frozen_string_literal: true

class CreateComPreferenceConsentReceipts < ActiveRecord::Migration[8.2]
  def change
    create_table(:com_preference_consent_receipts) do |t|
      t.references(:preference, null: false, foreign_key: { to_table: :com_preferences }, index: { unique: true })
      t.uuid(:version, null: false)
      t.datetime(:recorded_at, null: false)
      t.timestamps
    end
  end
end
