# typed: false
# frozen_string_literal: true

class RenameSideOrgOidcOperationalIdsToWarp < ActiveRecord::Migration[8.2]
  def up
    raise ActiveRecord::MigrationError, "conflicting org OIDC connection IDs" if conflicting_connection_ids?

    safety_assured do
      terminate_live_authorization_transactions!
      rename_connection_ids!
      rename_rp_session_ids!
      rename_authorization_transaction_ids!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Side-to-Warp operational ID migration is irreversible"
  end

  private

  def conflicting_connection_ids?
    connection.select_value(<<~SQL).to_i.positive?
      SELECT COUNT(*)
      FROM operator_oidc_connections old_rows
      JOIN operator_oidc_connections new_rows
        ON new_rows.staff_id = old_rows.staff_id
       AND new_rows.client_id = 'warp-org'
      WHERE old_rows.client_id = 'side-org'
    SQL
  end

  def terminate_live_authorization_transactions!
    execute <<~SQL
      UPDATE operator_oidc_authorization_transactions
      SET expires_at = LEAST(expires_at, CURRENT_TIMESTAMP), updated_at = CURRENT_TIMESTAMP
      WHERE client_id = 'side-org' AND status IN ('pending', 'authenticated')
    SQL
  end

  def rename_connection_ids!
    execute <<~SQL
      UPDATE operator_oidc_connections
      SET client_id = 'warp-org', updated_at = CURRENT_TIMESTAMP
      WHERE client_id = 'side-org'
    SQL
  end

  def rename_rp_session_ids!
    execute <<~SQL
      UPDATE operator_rp_sessions
      SET oidc_client_id = 'warp-org', updated_at = CURRENT_TIMESTAMP
      WHERE oidc_client_id = 'side-org'
    SQL
  end

  def rename_authorization_transaction_ids!
    execute <<~SQL
      UPDATE operator_oidc_authorization_transactions
      SET client_id = 'warp-org', updated_at = CURRENT_TIMESTAMP
      WHERE client_id = 'side-org'
    SQL
  end
end
