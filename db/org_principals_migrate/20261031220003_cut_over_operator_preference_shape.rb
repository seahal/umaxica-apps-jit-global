# frozen_string_literal: true

class CutOverOperatorPreferenceShape < ActiveRecord::Migration[8.2]
  class ReferenceRow < ActiveRecord::Base
    self.abstract_class = true
  end

  def up
    require_empty_table!(:operator_preferences)

    safety_assured do
      remove_foreign_key :operator_preferences, name: "fk_rails_9b2a21cc23"
      remove_index :operator_preferences, name: "index_operator_preferences_on_staff_id"
      rename_column :operator_preferences, :staff_id, :operator_id

      %i(
        language region timezone theme currency date_format time_format motion density page_size
        consented functional performant targetable consented_at consent_version
      ).each { |column| remove_column :operator_preferences, column }

      change_column_null :operator_preferences, :explicit_fields, false
      add_column :operator_preferences, :status_id, :bigint, default: 0, null: false
      create_table :operator_preference_statuses do |t|
      end
      seed_reference_rows(:operator_preference_statuses, [0, 1])

      add_foreign_key :operator_preferences, :operators,
                      column: :operator_id, name: "fk_operator_preferences_on_operator_id"
      add_foreign_key :operator_preferences, :operator_preference_statuses,
                      column: :status_id, name: "fk_operator_preferences_on_status_id"
      add_index :operator_preferences, :operator_id, unique: true, where: "status_id = 0",
                name: "index_operator_preferences_on_active_operator_id"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the legacy Preference values are not recoverable by DDL"
  end

  private

  def require_empty_table!(table_name)
    quoted_table = quote_table_name(table_name)
    return if select_value("SELECT 1 FROM #{quoted_table} LIMIT 1").nil?

    raise ActiveRecord::MigrationError,
          "#{table_name} must be empty before the approved WU-9 shape cutover"
  end

  def seed_reference_rows(table_name, ids)
    ReferenceRow.establish_connection(connection.pool.db_config)
    ReferenceRow.table_name = table_name.to_s
    ReferenceRow.primary_key = "id"
    ReferenceRow.insert_all(ids.map { |id| { id: id } })
  end
end
