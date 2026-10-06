# frozen_string_literal: true

class RetireLegacyAppSignUpHandoffStatuses < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      execute <<~SQL.squish
        UPDATE client_sign_up_flows
        SET status_id = 930, state = 'halted', step = 'halted', updated_at = CURRENT_TIMESTAMP
        WHERE status_id IN (70, 80)
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "legacy sign-up handoff retirement is irreversible"
  end
end
