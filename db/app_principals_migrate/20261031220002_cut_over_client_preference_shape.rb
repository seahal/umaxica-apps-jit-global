# frozen_string_literal: true

class CutOverClientPreferenceShape < ActiveRecord::Migration[8.2]
  def up
    require_empty_table!(:client_preferences)

    safety_assured do
      remove_foreign_key :client_preferences, name: "fk_rails_39373ef225"
      remove_index :client_preferences, name: "index_client_preferences_on_user_id"
      rename_column :client_preferences, :user_id, :client_id

      %i(
        language region timezone theme currency date_format time_format motion density page_size
        consented functional performant targetable consented_at consent_version
      ).each { |column| remove_column :client_preferences, column }

      change_column_null :client_preferences, :explicit_fields, false
      add_column :client_preferences, :status_id, :bigint, default: 0, null: false
      create_table :client_preference_statuses do |t|
      end
      seed_reference_rows(:client_preference_statuses, [0, 1])

      add_foreign_key :client_preferences, :clients,
                      column: :client_id, name: "fk_client_preferences_on_client_id", on_delete: :cascade
      add_foreign_key :client_preferences, :client_preference_statuses,
                      column: :status_id, name: "fk_client_preferences_on_status_id"
      add_index :client_preferences, :client_id, unique: true, where: "status_id = 0",
                name: "index_client_preferences_on_active_client_id"
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
    values = ids.map { |id| "(#{connection.quote(id)})" }.join(", ")
    execute "INSERT INTO #{quote_table_name(table_name)} (id) VALUES #{values}"
  end
end
