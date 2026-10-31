# frozen_string_literal: true

class DropComPreferenceDbscReferenceTables < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("LOCK TABLE com_preference_binding_methods, com_preference_dbsc_statuses IN ACCESS EXCLUSIVE MODE")
      if select_value(<<~SQL.squish)
        SELECT EXISTS (SELECT 1 FROM com_preference_binding_methods WHERE id NOT IN (0, 1, 2))
          OR EXISTS (SELECT 1 FROM com_preference_dbsc_statuses WHERE id NOT IN (0, 1, 2, 3, 4))
      SQL
        raise ActiveRecord::IrreversibleMigration, "unexpected DBSC references require an approved data disposition"
      end

      drop_table(:com_preference_binding_methods)
      drop_table(:com_preference_dbsc_statuses)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "restore the database backup to recover DBSC reference tables"
  end
end
