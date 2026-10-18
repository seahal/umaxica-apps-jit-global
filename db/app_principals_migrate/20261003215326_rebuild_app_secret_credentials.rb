# frozen_string_literal: true

class RebuildAppSecretCredentials < ActiveRecord::Migration[8.2]
  public

  # app-only destructive rebuild authorized by the Phase 1 contract. Applying this
  # migration requires an independently verified disposable database; old values
  # have no recovery or compatibility contract.
  def up
    drop_table(:client_secret_credentials)
    drop_table(:client_secret_credential_kinds)
    drop_table(:client_secret_credential_statuses)

    create_issuances
    create_credentials
    create_outboxes
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "old app Secret values were intentionally discarded"
  end

  private

  def create_issuances
    create_table(:client_secret_issuances) do |t|
      t.string(:public_id, limit: 21, null: false)
      t.references(:client, null: false, foreign_key: true)
      t.uuid(:origin_operation_id, null: false)
      t.string(:origin, null: false)
      t.integer(:attempt_number, null: false)
      t.string(:browser_session_ref)
      t.string(:sign_up_flow_ref)
      t.integer(:planned_count, null: false)
      t.datetime(:expires_at)
      t.datetime(:presented_at)
      t.datetime(:confirmed_at)
      t.datetime(:canceled_at)
      t.text(:encrypted_payload)
      t.datetime(:discard_at, null: false, default: Float::INFINITY)
      t.datetime(:purge_eligible_at, null: false, default: Float::INFINITY)
      t.timestamps
    end
    add_index(:client_secret_issuances, :public_id, unique: true)
    add_index(:client_secret_issuances, %i(origin_operation_id attempt_number), unique: true)
    add_index(:client_secret_issuances, %i(id client_id), unique: true)
    constrain_issuances
  end

  def constrain_issuances
    add_check_constraint(
      :client_secret_issuances,
      "origin IN ('manual', 'passkey_registration') AND attempt_number > 0 " \
      "AND planned_count BETWEEN 0 AND 2 AND (origin <> 'manual' OR planned_count <= 1)",
      name: "client_secret_issuance_count",
    )
    add_check_constraint(
      :client_secret_issuances,
      "(browser_session_ref IS NULL) <> (sign_up_flow_ref IS NULL)",
      name: "client_secret_issuance_binding",
    )
    add_check_constraint(
      :client_secret_issuances,
      "NOT (confirmed_at IS NOT NULL AND canceled_at IS NOT NULL) " \
      "AND (confirmed_at IS NULL OR (presented_at IS NOT NULL AND confirmed_at >= presented_at " \
      "AND confirmed_at < expires_at)) AND (presented_at IS NULL OR presented_at < expires_at)",
      name: "client_secret_issuance_facts",
    )
    add_check_constraint(
      :client_secret_issuances,
      "(planned_count = 0 AND expires_at IS NULL AND presented_at IS NULL " \
      "AND confirmed_at IS NULL AND canceled_at IS NULL AND encrypted_payload IS NULL) " \
      "OR (planned_count > 0 AND expires_at IS NOT NULL)",
      name: "client_secret_issuance_omission",
    )
  end

  def create_credentials
    create_table(:client_secret_credentials) do |t|
      t.string(:public_id, limit: 21, null: false)
      t.references(:client, null: false, foreign_key: true)
      t.bigint(:issuance_id, null: false)
      t.string(:name, limit: 255, null: false)
      t.string(:password_digest, limit: 255, null: false)
      t.string(:lookup_digest, limit: 64, null: false)
      t.datetime(:confirmed_at)
      t.datetime(:claimed_at)
      t.uuid(:claim_operation_id)
      t.datetime(:revoked_at)
      t.datetime(:discard_at, null: false, default: Float::INFINITY)
      t.datetime(:purge_eligible_at, null: false, default: Float::INFINITY)
      t.timestamps
      t.foreign_key(
        :client_secret_issuances,
        column: %i(issuance_id client_id), primary_key: %i(id client_id),
      )
    end
    add_index(:client_secret_credentials, :public_id, unique: true)
    add_index(:client_secret_credentials, :lookup_digest, unique: true)
    add_index(:client_secret_credentials, :claim_operation_id, unique: true)
    add_index(:client_secret_credentials, %i(issuance_id client_id))
    add_check_constraint(
      :client_secret_credentials,
      "(claimed_at IS NULL) = (claim_operation_id IS NULL) " \
      "AND (claimed_at IS NULL OR (confirmed_at IS NOT NULL AND claimed_at >= confirmed_at))",
      name: "client_secret_credential_claim",
    )
  end

  def create_outboxes
    create_table(:client_secret_audit_outboxes) do |t|
      t.uuid(:event_id, null: false)
      t.string(:event_name, limit: 128, null: false)
      t.string(:client_ref, limit: 21, null: false)
      t.string(:credential_ref, limit: 21)
      t.string(:actor_type)
      t.bigint(:actor_id)
      t.string(:actor_public_ref, limit: 21)
      t.string(:executor_job_id)
      t.uuid(:operation_ref, null: false)
      t.datetime(:occurred_at, null: false)
      t.string(:reason, limit: 128)
      t.integer(:item_count)
      t.datetime(:delivered_at)
      t.datetime(:discard_at, null: false, default: Float::INFINITY)
      t.datetime(:purge_eligible_at, null: false, default: Float::INFINITY)
      t.timestamps
    end
    add_index(:client_secret_audit_outboxes, :event_id, unique: true)
    add_index(:client_secret_audit_outboxes, %i(delivered_at occurred_at))
    add_check_constraint(
      :client_secret_audit_outboxes,
      "(actor_type IS NULL AND actor_id IS NULL AND actor_public_ref IS NULL) " \
      "OR (actor_type IS NOT NULL AND actor_type = 'Client' " \
      "AND actor_id IS NOT NULL AND actor_public_ref IS NOT NULL)",
      name: "client_secret_audit_actor",
    )
    add_check_constraint(
      :client_secret_audit_outboxes,
      "item_count IS NULL OR item_count BETWEEN 0 AND 20",
      name: "client_secret_audit_count",
    )
    add_check_constraint(
      :client_secret_audit_outboxes,
      "delivered_at IS NOT NULL OR purge_eligible_at = 'infinity'::timestamptz",
      name: "client_secret_audit_delivery_retention",
    )
  end
end
