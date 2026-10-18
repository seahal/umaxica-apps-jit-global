# frozen_string_literal: true
class RenameExpiresAtToPurgeAtAndAddLapsesAtOnChronicle < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
    tables = %w[app_preference_chronicles com_preference_chronicles org_preference_chronicles staff_chronicles user_chronicles]
    
    tables.each do |t|
      if table_exists?(t)
        add_column t, :discarded_at, :datetime, null: false, default: -> { "'infinity'" } unless column_exists?(t, :discarded_at)
        rename_column t, :expires_at, :purged_at if column_exists?(t, :expires_at)
      end
    end
    end
  end
end
