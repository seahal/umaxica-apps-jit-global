# typed: false
# frozen_string_literal: true

class NormalizeClientSessionLimitResolutionTransactions < ActiveRecord::Migration[8.2]
  STATE_IDS = [10, 20, 100, 910, 920].freeze

  def up
    create_state_table
    seed_states
    return unless table_exists?(:client_session_limit_resolution_transactions)

    add_normalized_columns
    normalize_existing_rows
    enforce_normalized_columns
    safety_assured do
      remove_column :client_session_limit_resolution_transactions, :status, :string if column_exists?(:client_session_limit_resolution_transactions, :status)
      remove_column :client_session_limit_resolution_transactions, :actor_type, :string if column_exists?(:client_session_limit_resolution_transactions, :actor_type)
    end

    safety_assured do
      add_foreign_key :client_session_limit_resolution_transactions, :client_session_limit_resolution_states,
                      column: :state_id, on_delete: :restrict, if_not_exists: true
      add_foreign_key :client_session_limit_resolution_transactions, :client_sign_in_flows,
                      column: :sign_in_flow_id, on_delete: :restrict, if_not_exists: true
      add_foreign_key :client_session_limit_resolution_transactions, :client_oidc_authorization_transactions,
                      column: :oidc_authorization_transaction_id, on_delete: :restrict, if_not_exists: true
    end
    safety_assured do
      add_index :client_session_limit_resolution_transactions, :sign_in_flow_id,
                unique: true, where: "state_id IN (10, 20)", name: "idx_client_resolution_open_parent", if_not_exists: true
      add_check_constraint :client_session_limit_resolution_transactions,
                          "(state_id = 10 AND selected_at IS NULL AND resolved_at IS NULL AND cancelled_at IS NULL AND expired_at IS NULL) OR (state_id = 20 AND selected_at IS NOT NULL AND resolved_at IS NULL AND cancelled_at IS NULL AND expired_at IS NULL) OR (state_id = 100 AND selected_at IS NOT NULL AND resolved_at IS NOT NULL AND cancelled_at IS NULL AND expired_at IS NULL) OR (state_id = 910 AND expired_at IS NOT NULL AND resolved_at IS NULL AND cancelled_at IS NULL) OR (state_id = 920 AND cancelled_at IS NOT NULL AND resolved_at IS NULL AND expired_at IS NULL)",
                          name: "chk_client_resolution_state_timestamps", if_not_exists: true
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "session-limit resolution state normalization is irreversible"
  end

  private

  def add_normalized_columns
    safety_assured do
      change_column_null :client_session_limit_resolution_transactions, :oidc_authorization_transaction_id, true
      add_column :client_session_limit_resolution_transactions, :state_id, :bigint unless column_exists?(:client_session_limit_resolution_transactions, :state_id)
      add_column :client_session_limit_resolution_transactions, :sign_in_flow_id, :bigint unless column_exists?(:client_session_limit_resolution_transactions, :sign_in_flow_id)
      add_column :client_session_limit_resolution_transactions, :browser_binding_digest, :string unless column_exists?(:client_session_limit_resolution_transactions, :browser_binding_digest)
      add_column :client_session_limit_resolution_transactions, :started_at, :datetime unless column_exists?(:client_session_limit_resolution_transactions, :started_at)
      add_column :client_session_limit_resolution_transactions, :expired_at, :datetime unless column_exists?(:client_session_limit_resolution_transactions, :expired_at)
      add_column :client_session_limit_resolution_transactions, :discard_at, :datetime, default: -> { "'infinity'::timestamp" } unless column_exists?(:client_session_limit_resolution_transactions, :discard_at)
      add_column :client_session_limit_resolution_transactions, :purge_eligible_at, :datetime, default: -> { "'infinity'::timestamp" } unless column_exists?(:client_session_limit_resolution_transactions, :purge_eligible_at)
      change_column_default :client_session_limit_resolution_transactions, :audit_context, from: nil, to: {} if column_exists?(:client_session_limit_resolution_transactions, :audit_context)
    end
  end

  def normalize_existing_rows
    return unless select_value("SELECT COUNT(*) FROM client_session_limit_resolution_transactions").to_i.positive?

    safety_assured do
      if column_exists?(:client_session_limit_resolution_transactions, :status)
        execute <<~SQL.squish
          UPDATE client_session_limit_resolution_transactions
          SET state_id = CASE status
            WHEN 'pending' THEN 10
            WHEN 'session_selected' THEN 20
            WHEN 'resolved' THEN 100
            WHEN 'expired' THEN 910
            WHEN 'cancelled' THEN 920
          END,
          started_at = COALESCE(started_at, created_at)
        SQL
      end

      execute <<~SQL.squish
        UPDATE client_session_limit_resolution_transactions AS resolution
        SET sign_in_flow_id = authorization.secret_sign_in_flow_id
        FROM client_oidc_authorization_transactions AS authorization
        WHERE resolution.oidc_authorization_transaction_id = authorization.id
          AND resolution.sign_in_flow_id IS NULL
      SQL
    end

    ambiguous_ids = select_values(<<~SQL.squish)
      SELECT resolution.id
      FROM client_session_limit_resolution_transactions AS resolution
      LEFT JOIN client_sign_in_flows AS flow ON flow.id = resolution.sign_in_flow_id
      WHERE resolution.sign_in_flow_id IS NULL OR flow.id IS NULL
         OR resolution.browser_binding_digest IS NULL
         OR resolution.browser_binding_digest = ''
         OR resolution.state_id IS NULL
         OR resolution.state_id NOT IN (10, 20, 100, 910, 920)
      ORDER BY resolution.id
    SQL
    return if ambiguous_ids.empty?

    raise ActiveRecord::MigrationError,
          "client session-limit resolution rows require forward repair (ids=#{ambiguous_ids.join(',')})"
  end

  def enforce_normalized_columns
    safety_assured do
      change_column_null :client_session_limit_resolution_transactions, :state_id, false
      change_column_null :client_session_limit_resolution_transactions, :sign_in_flow_id, false
      change_column_null :client_session_limit_resolution_transactions, :browser_binding_digest, false
      change_column_null :client_session_limit_resolution_transactions, :started_at, false
      change_column_null :client_session_limit_resolution_transactions, :discard_at, false
      change_column_null :client_session_limit_resolution_transactions, :purge_eligible_at, false
    end
  end

  def create_state_table
    return if table_exists?(:client_session_limit_resolution_states)

    create_table :client_session_limit_resolution_states do |t|
      t.timestamps
    end

    # This reference table is the target of foreign keys from an existing transaction table.
    # The test environment creates new tables UNLOGGED, while a structure-loaded transaction
    # table can already be LOGGED; PostgreSQL rejects that mixed FK. The state authority is
    # durable reference data and must remain readable by replicas as well.
    safety_assured { execute("ALTER TABLE client_session_limit_resolution_states SET LOGGED") }
  end

  def seed_states
    safety_assured do
      STATE_IDS.each do |id|
        execute "INSERT INTO client_session_limit_resolution_states (id, created_at, updated_at) VALUES (#{id}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ON CONFLICT (id) DO NOTHING"
      end
    end
  end
end
