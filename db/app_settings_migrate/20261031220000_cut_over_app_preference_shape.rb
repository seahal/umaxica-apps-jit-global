# frozen_string_literal: true

class CutOverAppPreferenceShape < ActiveRecord::Migration[8.2]
  class ReferenceRow < ActiveRecord::Base
    self.abstract_class = true
  end

  def up
    require_empty_table!(:app_preferences)

    safety_assured do
      remove_foreign_key :app_preferences, name: "fk_app_preferences_on_binding_method_id"
      remove_foreign_key :app_preferences, name: "fk_app_preferences_on_dbsc_status_id"
      remove_foreign_key :app_preferences, name: "fk_rails_40612c8731"
      remove_foreign_key :app_preferences, name: "fk_app_preferences_on_status_id"

      %w(
        index_app_preferences_on_binding_method_id
        index_app_preferences_on_dbsc_session_id
        index_app_preferences_on_dbsc_status_id
        index_app_preferences_on_purge_eligible_at
        index_app_preferences_on_replaced_by_id
        index_app_preferences_on_token_digest
        index_app_preferences_on_used_at
      ).each { |index_name| remove_index :app_preferences, name: index_name }

      %i(
        binding_method_id dbsc_status_id dbsc_challenge dbsc_challenge_issued_at dbsc_public_key
        dbsc_session_id token_digest used_at replaced_by_id purge_eligible_at discard_at explicit_fields
      ).each { |column| remove_column :app_preferences, column }
      change_column_null :app_preferences, :jti, false
      add_column :app_preferences, :last_issued_at, :datetime, precision: 6, null: false
      add_column :app_preferences, :last_issued_expires_at, :datetime, precision: 6, null: false

      remove_column :app_preference_cookies, :consent_version
      remove_column :app_preference_cookies, :consented_at

      drop_table :app_preference_binding_methods
      drop_table :app_preference_dbsc_statuses
      drop_table :app_preference_statuses
      create_table :app_preference_statuses do |t|
      end
      seed_reference_rows(:app_preference_statuses, [0, 1])

      add_foreign_key :app_preferences, :app_preference_statuses,
                      column: :status_id, name: "fk_app_preferences_on_status_id"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the legacy Preference columns and values are not recoverable by DDL"
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
