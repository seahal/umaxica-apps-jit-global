# frozen_string_literal: true

class AddComPreferenceIssuanceSnapshot < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("LOCK TABLE com_preferences IN ACCESS EXCLUSIVE MODE")
      if select_value("SELECT EXISTS (SELECT 1 FROM com_preferences)")
        raise ActiveRecord::IrreversibleMigration, "existing preferences need an approved issuance data disposition"
      end

      # Existing rows are refused above; fabricating an issuance timestamp would misrepresent them.
      execute("ALTER TABLE com_preferences ADD COLUMN last_issued_at timestamp(6) with time zone NOT NULL")
      execute("ALTER TABLE com_preferences ADD COLUMN last_issued_expires_at timestamp(6) with time zone NOT NULL")
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "restore a backup to recover issuance snapshots"
  end
end
