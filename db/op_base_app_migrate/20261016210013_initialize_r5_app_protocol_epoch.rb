# typed: false
# frozen_string_literal: true

class InitializeR5AppProtocolEpoch < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute(<<~SQL)
        INSERT INTO op_protocol_epochs
          (id, realm, contract_epoch, changed_at, created_at, updated_at)
        VALUES
          (1, 'app', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (id) DO NOTHING
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "R5 protocol epoch initialization is forward-only"
  end
end
