# frozen_string_literal: true

class CutOverOrgPreferenceShape < ActiveRecord::Migration[8.2]
  def up
    require_empty_table!(:org_preferences)

    safety_assured do
      remove_foreign_key :org_preferences, name: "fk_org_preferences_on_binding_method_id"
      remove_foreign_key :org_preferences, name: "fk_org_preferences_on_dbsc_status_id"
      remove_foreign_key :org_preferences, name: "fk_rails_981b4c7c84"

      %w(
        index_org_preferences_on_binding_method_id
        index_org_preferences_on_dbsc_session_id
        index_org_preferences_on_dbsc_status_id
        index_org_preferences_on_purge_eligible_at
        index_org_preferences_on_replaced_by_id
        index_org_preferences_on_token_digest
        index_org_preferences_on_used_at
      ).each { |index_name| remove_index :org_preferences, name: index_name }

      %i(
        binding_method_id dbsc_status_id dbsc_challenge dbsc_challenge_issued_at dbsc_public_key
        dbsc_session_id token_digest used_at replaced_by_id purge_eligible_at discard_at explicit_fields
      ).each { |column| remove_column :org_preferences, column }
      change_column_null :org_preferences, :jti, false
      add_column :org_preferences, :last_issued_at, :datetime, precision: 6, null: false
      add_column :org_preferences, :last_issued_expires_at, :datetime, precision: 6, null: false

      remove_column :org_preference_cookies, :consent_version
      remove_column :org_preference_cookies, :consented_at

      drop_table :org_preference_binding_methods
      drop_table :org_preference_dbsc_statuses
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
end
