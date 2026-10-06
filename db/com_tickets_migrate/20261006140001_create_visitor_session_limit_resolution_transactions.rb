# typed: false
# frozen_string_literal: true

class CreateVisitorSessionLimitResolutionTransactions < ActiveRecord::Migration[8.2]
  STATE_IDS = [10, 20, 100, 910, 920].freeze

  def up
    create_table :visitor_session_limit_resolution_states do |t|
      t.timestamps
    end unless table_exists?(:visitor_session_limit_resolution_states)

    # This reference table is durable state and the target of foreign keys. Keep it LOGGED even
    # when the test environment defaults newly created tables to UNLOGGED.
    safety_assured { execute("ALTER TABLE visitor_session_limit_resolution_states SET LOGGED") } if
      table_exists?(:visitor_session_limit_resolution_states)

    safety_assured do
      STATE_IDS.each do |id|
        execute "INSERT INTO visitor_session_limit_resolution_states (id, created_at, updated_at) VALUES (#{id}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ON CONFLICT (id) DO NOTHING"
      end
    end

    create_table :visitor_session_limit_resolution_transactions do |t|
      t.string :challenge_digest, null: false
      t.bigint :state_id, null: false
      t.bigint :sign_in_flow_id, null: false
      t.bigint :oidc_authorization_transaction_id
      t.string :actor_ref, null: false
      t.string :browser_binding_digest, null: false
      t.string :selected_session_ref
      t.datetime :started_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :selected_at
      t.datetime :resolved_at
      t.datetime :cancelled_at
      t.datetime :expired_at
      t.datetime :consumed_at
      t.datetime :finalized_at
      t.jsonb :audit_context, null: false, default: {}
      t.datetime :discard_at, null: false, default: -> { "'infinity'::timestamp" }
      t.datetime :purge_eligible_at, null: false, default: -> { "'infinity'::timestamp" }
      t.timestamps
    end unless table_exists?(:visitor_session_limit_resolution_transactions)

    safety_assured do
      add_foreign_key :visitor_session_limit_resolution_transactions, :visitor_session_limit_resolution_states, column: :state_id, on_delete: :restrict, if_not_exists: true
      add_foreign_key :visitor_session_limit_resolution_transactions, :visitor_sign_in_flows, column: :sign_in_flow_id, on_delete: :restrict, if_not_exists: true
      add_foreign_key :visitor_session_limit_resolution_transactions, :visitor_oidc_authorization_transactions, column: :oidc_authorization_transaction_id, on_delete: :restrict, if_not_exists: true
    end
    safety_assured do
      add_index :visitor_session_limit_resolution_transactions, :challenge_digest, unique: true, if_not_exists: true
      add_index :visitor_session_limit_resolution_transactions, :sign_in_flow_id, unique: true, where: "state_id IN (10, 20)", name: "idx_visitor_resolution_open_parent", if_not_exists: true
      add_check_constraint :visitor_session_limit_resolution_transactions, "(state_id = 10 AND selected_at IS NULL AND resolved_at IS NULL AND cancelled_at IS NULL AND expired_at IS NULL) OR (state_id = 20 AND selected_at IS NOT NULL AND resolved_at IS NULL AND cancelled_at IS NULL AND expired_at IS NULL) OR (state_id = 100 AND selected_at IS NOT NULL AND resolved_at IS NOT NULL AND cancelled_at IS NULL AND expired_at IS NULL) OR (state_id = 910 AND expired_at IS NOT NULL AND resolved_at IS NULL AND cancelled_at IS NULL) OR (state_id = 920 AND cancelled_at IS NOT NULL AND resolved_at IS NULL AND expired_at IS NULL)", name: "chk_visitor_resolution_state_timestamps", if_not_exists: true
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "session-limit resolution state tables are migration-owned"
  end
end
