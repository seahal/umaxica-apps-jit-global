# frozen_string_literal: true

class RemoveComPreferenceDbscReferences < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("LOCK TABLE com_preferences IN ACCESS EXCLUSIVE MODE")
      if select_value("SELECT EXISTS (SELECT 1 FROM com_preferences WHERE binding_method_id <> 0 OR dbsc_status_id <> 0)")
        raise ActiveRecord::IrreversibleMigration, "non-default DBSC state requires an approved data disposition"
      end

      remove_column(:com_preferences, :binding_method_id)
      remove_column(:com_preferences, :dbsc_status_id)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "restore the database backup to recover DBSC references"
  end
end
