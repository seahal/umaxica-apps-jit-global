# typed: false
# frozen_string_literal: true

class RenameSideAppOidcOperationalIdsToWarp < ActiveRecord::Migration[8.2]
  def up
    raise ActiveRecord::MigrationError, "conflicting app OIDC connection IDs" if conflicting_connection_ids?

    safety_assured do
      terminate_live_authorization_transactions!
      rename_connection_ids!
      rename_rp_session_ids!
      rename_authorization_transaction_ids!
      rename_logout_ids!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Side-to-Warp operational ID migration is irreversible"
  end

  private

  def conflicting_connection_ids?
    connection.select_value(<<~SQL).to_i.positive?
      SELECT COUNT(*)
      FROM client_oidc_connections old_rows
      JOIN client_oidc_connections new_rows
        ON new_rows.user_id = old_rows.user_id
       AND new_rows.client_id = 'warp-app'
      WHERE old_rows.client_id = 'side-app'
    SQL
  end

  def terminate_live_authorization_transactions!
    execute <<~SQL
      UPDATE client_oidc_authorization_transactions
      SET expires_at = LEAST(expires_at, CURRENT_TIMESTAMP), updated_at = CURRENT_TIMESTAMP
      WHERE client_id = 'side-app' AND status IN ('pending', 'authenticated')
    SQL
  end

  def rename_connection_ids!
    execute <<~SQL
      UPDATE client_oidc_connections
      SET client_id = 'warp-app', updated_at = CURRENT_TIMESTAMP
      WHERE client_id = 'side-app'
    SQL
  end

  def rename_rp_session_ids!
    execute <<~SQL
      UPDATE client_rp_sessions
      SET oidc_client_id = 'warp-app', updated_at = CURRENT_TIMESTAMP
      WHERE oidc_client_id = 'side-app'
    SQL
  end

  def rename_authorization_transaction_ids!
    execute <<~SQL
      UPDATE client_oidc_authorization_transactions
      SET client_id = 'warp-app', updated_at = CURRENT_TIMESTAMP
      WHERE client_id = 'side-app'
    SQL
  end

  def rename_logout_ids!
    execute <<~SQL
      UPDATE acme_logout_transactions
      SET status = CASE
                    WHEN origin_surface = 'side' AND status IN ('initiated', 'in_progress')
                      THEN 'expired'
                    ELSE status
                  END,
          expires_at = CASE
                         WHEN origin_surface = 'side' AND status IN ('initiated', 'in_progress')
                           THEN LEAST(expires_at, CURRENT_TIMESTAMP)
                         ELSE expires_at
                       END,
          origin_surface = CASE origin_surface WHEN 'side' THEN 'warp' ELSE origin_surface END,
          initiating_client_id = CASE initiating_client_id
                                   WHEN 'side-app' THEN 'warp-app'
                                   ELSE initiating_client_id
                                 END,
          updated_at = CURRENT_TIMESTAMP
      WHERE origin_surface = 'side' OR initiating_client_id = 'side-app'
    SQL
  end
end
