# frozen_string_literal: true

class RemoveComPreferenceLegacyConsentMetadata < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("LOCK TABLE com_preference_cookies IN ACCESS EXCLUSIVE MODE")
      if select_value(<<~SQL.squish)
        SELECT EXISTS (SELECT 1 FROM com_preference_cookies
          WHERE consent_version IS NOT NULL OR consented_at IS NOT NULL)
      SQL
        raise ActiveRecord::IrreversibleMigration, "legacy consent metadata requires an approved data disposition"
      end

      remove_column(:com_preference_cookies, :consent_version)
      remove_column(:com_preference_cookies, :consented_at)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "restore the database backup to recover legacy consent metadata"
  end
end
