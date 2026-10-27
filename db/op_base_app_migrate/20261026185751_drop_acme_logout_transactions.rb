# frozen_string_literal: true

class DropAcmeLogoutTransactions < ActiveRecord::Migration[8.2]
  def up
    drop_table(:acme_logout_transactions)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the retired logout transaction data cannot be restored"
  end
end
