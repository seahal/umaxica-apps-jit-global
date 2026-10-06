# typed: false
# frozen_string_literal: true

class AddBrowserRpLogoutWorkflow < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      add_column :acme_logout_transactions, :workflow, :string, null: false, default: "legacy",
                                                  if_not_exists: true
      add_index :acme_logout_transactions, :workflow, if_not_exists: true

      execute <<~SQL
        UPDATE acme_logout_transactions
        SET status = 'expired',
            expires_at = LEAST(expires_at, CURRENT_TIMESTAMP),
            updated_at = CURRENT_TIMESTAMP
        WHERE workflow = 'legacy'
          AND origin_surface IN ('base', 'core', 'warp', 'edit')
          AND status IN ('initiated', 'in_progress')
      SQL
    end
  end

  def down
    remove_index :acme_logout_transactions, column: :workflow, if_exists: true
    remove_column :acme_logout_transactions, :workflow, if_exists: true
  end
end
