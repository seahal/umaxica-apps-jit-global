# frozen_string_literal: true

class RequireComPreferenceJti < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("LOCK TABLE com_preferences IN ACCESS EXCLUSIVE MODE")
      if select_value("SELECT EXISTS (SELECT 1 FROM com_preferences WHERE jti IS NULL)")
        raise ActiveRecord::IrreversibleMigration, "missing generations require an approved data disposition"
      end

      change_column_null(:com_preferences, :jti, false)
    end
  end

  def down
    change_column_null(:com_preferences, :jti, true)
  end
end
