# frozen_string_literal: true

class RemoveComPreferenceDbscState < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("LOCK TABLE com_preferences IN ACCESS EXCLUSIVE MODE")
      if select_value(<<~SQL.squish)
        SELECT EXISTS (SELECT 1 FROM com_preferences WHERE dbsc_challenge IS NOT NULL
          OR dbsc_challenge_issued_at IS NOT NULL OR dbsc_public_key IS NOT NULL OR dbsc_session_id IS NOT NULL)
      SQL
        raise ActiveRecord::IrreversibleMigration, "populated DBSC state requires an approved data disposition"
      end

      remove_column(:com_preferences, :dbsc_challenge)
      remove_column(:com_preferences, :dbsc_challenge_issued_at)
      remove_column(:com_preferences, :dbsc_public_key)
      remove_column(:com_preferences, :dbsc_session_id)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "restore the database backup to recover DBSC state"
  end
end
