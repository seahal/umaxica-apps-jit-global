# frozen_string_literal: true

class DropOpAppAuthorityStopBrowserLogouts < ActiveRecord::Migration[8.2]
  def up
    drop_table(:op_app_authority_stop_browser_logouts)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the retired browser logout receipts cannot be restored"
  end
end
