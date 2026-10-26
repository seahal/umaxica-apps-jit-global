# frozen_string_literal: true

# WU-16 (two.md 5.8 v2, D-119, D-123, D-158 P-142, D-172, D-173): the browser-independent OP
# authority-stop record. Every column is NOT NULL; no NULL carries meaning. Children reference the
# stop and their targets ON DELETE RESTRICT; retention purges children first (S-2).
class CreateOpAuthorityStopsOpBaseCom < ActiveRecord::Migration[8.2]
  REALM = "com"
  ROOT_TABLE = :visitor_tokens
  GRANT_TABLE = :op_com_grants
  CAUSES = {
    1 => "browser_logout",
    2 => "rp_initiated_logout",
    3 => "token_revocation",
    4 => "refresh_reuse",
    5 => "revoke_others",
    6 => "credential_change",
    7 => "identity_stop",
    8 => "administrative",
    9 => "risk",
  }.freeze
  SCOPES = { 1 => "root", 2 => "grant", 3 => "all_roots_of_principal" }.freeze
  PARTICIPANT_STATUSES = { 1 => "pending", 2 => "acknowledged", 3 => "refused", 4 => "expired" }.freeze

  def up
    create_reference_tables
    create_authority_stops_table
    create_root_targets_table
    create_grant_targets_table
    create_epoch_cutoffs_table
    create_participants_table
    create_browser_logouts_table
  end

  def down
    %i(
      op_authority_stop_browser_logouts op_authority_stop_participants op_authority_stop_epoch_cutoffs
      op_authority_stop_grant_targets op_authority_stop_root_targets op_authority_stops
      op_authority_stop_participant_statuses op_authority_stop_scopes op_authority_stop_causes
    ).each { |table| drop_table(table) }
  end

  private

  def create_reference_tables
    %i(op_authority_stop_causes op_authority_stop_scopes op_authority_stop_participant_statuses).each do |table|
      create_table(table, id: :bigint)
    end
    seed_reference(:op_authority_stop_causes, CAUSES)
    seed_reference(:op_authority_stop_scopes, SCOPES)
    seed_reference(:op_authority_stop_participant_statuses, PARTICIPANT_STATUSES)
  end

  def create_authority_stops_table
    create_table(:op_authority_stops) do |t|
      t.string(:public_id, limit: 21, null: false, index: { unique: true })
      t.string(:realm, limit: 3, null: false)
      t.references(:cause, null: false, index: true, foreign_key: { to_table: :op_authority_stop_causes })
      t.references(:scope, null: false, index: true, foreign_key: { to_table: :op_authority_stop_scopes })
      t.string(:principal_public_id, limit: 255, null: false, index: true)
      t.string(:authority_evidence_ref, limit: 128, null: false)
      t.binary(:idempotency_digest, null: false)
      t.datetime(:occurred_at, null: false)
      t.timestamps
    end
    add_index(:op_authority_stops, %i(realm idempotency_digest), unique: true)
    add_check_constraint(
      :op_authority_stops, "realm = '#{REALM}'", name: "chk_op_#{REALM}_authority_stops_realm",
    )
  end

  def create_root_targets_table
    create_table(:op_authority_stop_root_targets) do |t|
      t.references(:stop, null: false, index: false, foreign_key: { to_table: :op_authority_stops })
      t.references(:root, null: false, index: true, foreign_key: { to_table: ROOT_TABLE })
      t.timestamps
    end
    add_index(:op_authority_stop_root_targets, %i(stop_id root_id), unique: true)
  end

  def create_grant_targets_table
    create_table(:op_authority_stop_grant_targets) do |t|
      t.references(:stop, null: false, index: false, foreign_key: { to_table: :op_authority_stops })
      t.references(:grant, null: false, index: true, foreign_key: { to_table: GRANT_TABLE })
      t.timestamps
    end
    add_index(:op_authority_stop_grant_targets, %i(stop_id grant_id), unique: true)
  end

  def create_epoch_cutoffs_table
    create_table(:op_authority_stop_epoch_cutoffs) do |t|
      t.references(:stop, null: false, index: { unique: true }, foreign_key: { to_table: :op_authority_stops })
      t.bigint(:cutoff_epoch, null: false)
      t.timestamps
    end
    add_check_constraint(
      :op_authority_stop_epoch_cutoffs, "cutoff_epoch >= 1", name: "chk_op_#{REALM}_stop_cutoffs_epoch",
    )
  end

  def create_participants_table
    create_table(:op_authority_stop_participants) do |t|
      t.references(:stop, null: false, index: true, foreign_key: { to_table: :op_authority_stops })
      t.references(:grant, null: false, index: true, foreign_key: { to_table: GRANT_TABLE })
      t.references(
        :status, null: false, index: false, foreign_key: { to_table: :op_authority_stop_participant_statuses },
      )
      t.string(:issuer, limit: 255, null: false)
      t.string(:client_id, limit: 64, null: false)
      t.string(:sid, limit: 255, null: false)
      t.string(:endpoint_identity, limit: 255, null: false)
      t.integer(:delivery_attempts, null: false, default: 0)
      t.datetime(:next_attempt_at, null: false)
      t.datetime(:deadline_at, null: false)
      t.datetime(:lease_expires_at, null: false)
      t.string(:last_outcome, limit: 64, null: false)
      t.timestamps
    end
    add_index(:op_authority_stop_participants, %i(stop_id grant_id), unique: true)
    add_index(:op_authority_stop_participants, %i(status_id next_attempt_at))
    add_check_constraint(
      :op_authority_stop_participants, "delivery_attempts >= 0 AND deadline_at >= created_at",
      name: "chk_op_#{REALM}_stop_participants_shape",
    )
  end

  def create_browser_logouts_table
    create_table(:op_authority_stop_browser_logouts) do |t|
      t.references(:stop, null: false, index: { unique: true }, foreign_key: { to_table: :op_authority_stops })
      t.binary(:browser_binding_digest, null: false)
      t.binary(:receipt_nonce_digest, null: false)
      t.datetime(:receipt_expires_at, null: false)
      t.boolean(:receipt_consumed, null: false, default: false)
      t.timestamps
    end
  end

  def seed_reference(table, rows)
    values = rows.keys.map { |id| "(#{Integer(id)})" }.join(", ")
    safety_assured { execute("INSERT INTO #{quote_table_name(table)} (id) VALUES #{values}") }
  end
end
