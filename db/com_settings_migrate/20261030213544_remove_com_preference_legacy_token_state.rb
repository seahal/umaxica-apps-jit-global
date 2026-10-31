# frozen_string_literal: true

class RemoveComPreferenceLegacyTokenState < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("LOCK TABLE com_preferences IN ACCESS EXCLUSIVE MODE")
      if select_value(<<~SQL.squish)
        SELECT EXISTS (SELECT 1 FROM com_preferences
          WHERE token_digest IS NOT NULL OR used_at IS NOT NULL OR replaced_by_id IS NOT NULL)
      SQL
        raise ActiveRecord::IrreversibleMigration, "legacy token state requires an approved data disposition"
      end

      remove_column(:com_preferences, :token_digest)
      remove_column(:com_preferences, :used_at)
      remove_column(:com_preferences, :replaced_by_id)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "restore the database backup to recover legacy token state"
  end
end
