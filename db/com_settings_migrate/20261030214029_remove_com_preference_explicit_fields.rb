# frozen_string_literal: true

class RemoveComPreferenceExplicitFields < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("LOCK TABLE com_preferences IN ACCESS EXCLUSIVE MODE")
      if select_value("SELECT EXISTS (SELECT 1 FROM com_preferences WHERE explicit_fields <> '[]'::jsonb)")
        raise ActiveRecord::IrreversibleMigration, "explicit preference metadata requires an approved data disposition"
      end

      remove_column(:com_preferences, :explicit_fields)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "restore the database backup to recover explicit preference metadata"
  end
end
