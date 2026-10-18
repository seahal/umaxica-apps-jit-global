# typed: false
# frozen_string_literal: true

class CreateR5ComProtocolFoundation < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  CONTRACT_TABLES = %i(visitor_tokens op_com_grants visitor_oidc_authorization_transactions).freeze
  CONTRACT_CONSTRAINTS = {
    visitor_tokens: "chk_visitor_tokens_contract_epoch",
    op_com_grants: "chk_op_com_grants_contract_epoch",
    visitor_oidc_authorization_transactions: "chk_visitor_oidc_authorization_transactions_contract_epoch",
  }.freeze

  def up
    add_contract_epoch_columns!
    create_protocol_epoch!
    create_consumed_jtis!
    create_logout_flow!
    create_logout_flow_participants!
    create_logout_receipts!
    create_outbox_events!
    create_inbound_event_receipts!
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "R5 protocol state is forward-only"
  end

  private

  def add_contract_epoch_columns!
    safety_assured do
      CONTRACT_TABLES.each do |table|
        add_column(table, :contract_epoch, :bigint) unless column_exists?(table, :contract_epoch)
      end
    end

    CONTRACT_TABLES.each do |table|
      add_check_constraint(
        table,
        "contract_epoch IS NULL OR contract_epoch >= 1",
        name: CONTRACT_CONSTRAINTS.fetch(table),
        if_not_exists: true,
        validate: false,
      )
    end
  end

  def create_protocol_epoch!
    create_table(:op_protocol_epochs, id: :bigint, if_not_exists: true) do |t|
      t.string(:realm, null: false, limit: 3)
      t.bigint(:contract_epoch, null: false, default: 1)
      t.datetime(:changed_at, null: false)
      t.timestamps
    end
    add_index(:op_protocol_epochs, :realm, unique: true, name: "idx_op_protocol_epochs_realm", if_not_exists: true)
    add_check_constraint(
      :op_protocol_epochs,
      "id = 1",
      name: "chk_op_protocol_epochs_singleton",
      if_not_exists: true,
      validate: false,
    )
    add_check_constraint(
      :op_protocol_epochs,
      "realm = 'com' AND contract_epoch >= 1",
      name: "chk_op_protocol_epochs_com_shape",
      if_not_exists: true,
      validate: false,
    )
    safety_assured do
      execute(<<~SQL)
        INSERT INTO op_protocol_epochs
          (id, realm, contract_epoch, changed_at, created_at, updated_at)
        VALUES
          (1, 'com', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (id) DO NOTHING
      SQL
    end
  end

  def create_consumed_jtis!
    create_table(:op_consumed_jtis, id: :bigserial, if_not_exists: true) do |t|
      t.string(:purpose, null: false, limit: 64)
      t.string(:issuer, null: false, limit: 255)
      t.string(:realm, null: false, limit: 3)
      t.string(:client_id, null: false, limit: 64)
      t.string(:jti_digest, null: false, limit: 64)
      t.datetime(:expires_at, null: false)
      t.datetime(:consumed_at, null: false)
      t.timestamps
    end
    add_index(
      :op_consumed_jtis, %i(purpose issuer realm client_id jti_digest), unique: true,
      name: "idx_op_com_consumed_jtis_scope", if_not_exists: true,
    )
    add_index(:op_consumed_jtis, :expires_at, name: "idx_op_com_consumed_jtis_expires_at", if_not_exists: true)
    add_check_constraint(:op_consumed_jtis, "realm = 'com'", name: "chk_op_com_consumed_jtis_realm", if_not_exists: true, validate: false)
  end

  def create_logout_flow!
    create_table(:logout_flows, id: :bigserial, if_not_exists: true) do |t|
      t.string(:public_id, null: false, limit: 21)
      t.string(:realm, null: false, limit: 3)
      t.string(:target_root_ref, null: false, limit: 255)
      t.binary(:idempotency_digest, null: false, limit: 32)
      t.binary(:browser_binding_digest, null: false, limit: 32)
      t.datetime(:expires_at, null: false)
      t.datetime(:op_revoked_at)
      t.string(:audit_ref, null: false, limit: 128)
      t.timestamps
    end
    add_index(:logout_flows, :public_id, unique: true, name: "idx_op_com_logout_flows_public_id", if_not_exists: true)
    add_index(
      :logout_flows, %i(realm idempotency_digest), unique: true,
      name: "idx_op_com_logout_flows_idempotency", if_not_exists: true,
    )
    add_check_constraint(:logout_flows, "realm = 'com'", name: "chk_op_com_logout_flows_realm", if_not_exists: true, validate: false)
  end

  def create_logout_flow_participants!
    create_table(:logout_flow_participants, id: :bigserial, if_not_exists: true) do |t|
      t.references(:logout_flow, null: false, foreign_key: true, index: false)
      t.string(:issuer, null: false, limit: 255)
      t.string(:realm, null: false, limit: 3)
      t.string(:client_id, null: false, limit: 64)
      t.string(:sid, null: false, limit: 255)
      t.string(:endpoint_identity, null: false, limit: 255)
      t.integer(:delivery_attempts, null: false, default: 0)
      t.datetime(:next_attempt_at)
      t.datetime(:lease_expires_at)
      t.datetime(:dispatched_at)
      t.datetime(:acknowledged_at)
      t.datetime(:purge_response_at)
      t.datetime(:completed_at)
      t.string(:last_error_code, limit: 64)
      t.timestamps
    end
    add_index(
      :logout_flow_participants, %i(logout_flow_id issuer realm client_id sid), unique: true,
      name: "idx_op_com_logout_participants_identity", if_not_exists: true,
    )
    add_check_constraint(
      :logout_flow_participants, "realm = 'com' AND delivery_attempts >= 0",
      name: "chk_op_com_logout_participants_shape", if_not_exists: true,
      validate: false,
    )
  end

  def create_logout_receipts!
    create_table(:logout_receipts, id: :bigserial, if_not_exists: true) do |t|
      t.references(:logout_flow, null: false, foreign_key: true, index: false)
      t.string(:public_id, null: false, limit: 21)
      t.binary(:nonce_digest, null: false, limit: 32)
      t.binary(:browser_binding_digest, null: false, limit: 32)
      t.datetime(:expires_at, null: false)
      t.datetime(:consumed_at)
      t.timestamps
    end
    add_index(:logout_receipts, :public_id, unique: true, name: "idx_op_com_logout_receipts_public_id", if_not_exists: true)
    add_index(
      :logout_receipts, %i(logout_flow_id nonce_digest), unique: true,
      name: "idx_op_com_logout_receipts_nonce", if_not_exists: true,
    )
  end

  def create_outbox_events!
    create_table(:op_outbox_events, id: :bigserial, if_not_exists: true) do |t|
      t.uuid(:event_id, null: false, default: -> { "gen_random_uuid()" })
      t.references(:logout_flow_participant, foreign_key: true, index: false)
      t.string(:event_type, null: false, limit: 64)
      t.string(:target_realm, null: false, limit: 3)
      t.string(:target_client_id, null: false, limit: 64)
      t.string(:target_endpoint_identity, null: false, limit: 255)
      t.string(:stable_event_ref, null: false, limit: 128)
      t.integer(:delivery_attempts, null: false, default: 0)
      t.datetime(:next_attempt_at, null: false)
      t.datetime(:lease_expires_at)
      t.datetime(:dispatched_at)
      t.datetime(:completed_at)
      t.string(:last_error_code, limit: 64)
      t.timestamps
    end
    add_index(:op_outbox_events, :event_id, unique: true, name: "idx_op_com_outbox_events_event_id", if_not_exists: true)
    add_index(:op_outbox_events, :next_attempt_at, name: "idx_op_com_outbox_events_next_attempt", if_not_exists: true)
    add_check_constraint(
      :op_outbox_events,
      "target_realm = 'com' AND delivery_attempts >= 0",
      name: "chk_op_com_outbox_events_shape", if_not_exists: true,
      validate: false,
    )
  end

  def create_inbound_event_receipts!
    create_table(:op_inbound_event_receipts, id: :bigserial, if_not_exists: true) do |t|
      t.uuid(:event_id, null: false)
      t.string(:issuer, null: false, limit: 255)
      t.string(:realm, null: false, limit: 3)
      t.string(:client_id, null: false, limit: 64)
      t.string(:event_type, null: false, limit: 64)
      t.datetime(:committed_at, null: false)
      t.timestamps
    end
    add_index(
      :op_inbound_event_receipts, %i(event_id issuer realm client_id), unique: true,
      name: "idx_op_com_inbound_event_receipts_identity", if_not_exists: true,
    )
    add_check_constraint(
      :op_inbound_event_receipts, "realm = 'com'",
      name: "chk_op_com_inbound_event_receipts_realm", if_not_exists: true,
      validate: false,
    )
  end
end
