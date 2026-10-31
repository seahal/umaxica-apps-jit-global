# frozen_string_literal: true

class RemoveComPreferenceLegacyRetention < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("LOCK TABLE com_preferences IN ACCESS EXCLUSIVE MODE")
      if select_value("SELECT EXISTS (SELECT 1 FROM com_preferences)")
        raise ActiveRecord::IrreversibleMigration, "legacy retention requires an approved data disposition"
      end

      remove_column(:com_preferences, :discard_at)
      remove_column(:com_preferences, :purge_eligible_at)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "restore the database backup to recover legacy retention"
  end
end
