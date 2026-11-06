# frozen_string_literal: true

class CreateRpBaseAppStepUpPersistence < ActiveRecord::Migration[8.2]
  def change
    create_state_tables
    create_audit_outbox
    add_audit_outbox_constraints
    create_audit_attempts
  end

  private

  def create_state_tables
    create_table(:rp_step_up_state_statuses, id: :bigint)

    create_table(:rp_step_up_states) do |t|
      t.string(:public_id, null: false, limit: 21)
      t.references(:rp_session, null: false, foreign_key: { to_table: :rp_sessions })
      t.string(:state_digest, null: false, limit: 64)
      t.string(:browser_binding_digest, null: false, limit: 64)
      t.string(:nonce_digest, null: false, limit: 64)
      t.string(:pkce_challenge, null: false, limit: 128)
      t.text(:pkce_verifier_ciphertext, null: false)
      t.string(:issuer, null: false, limit: 255)
      t.string(:realm, null: false, limit: 3)
      t.string(:client_id, null: false, limit: 64)
      t.string(:return_target, null: false, limit: 512)
      t.bigint(:initiating_generation, null: false)
      t.references(:state, null: false, foreign_key: { to_table: :rp_step_up_state_statuses })
      t.datetime(:expires_at, null: false)
      t.timestamps(null: false)
    end

    add_index(:rp_step_up_states, :public_id, unique: true, name: "idx_rp_step_up_states_public_id")
    add_index(:rp_step_up_states, :state_digest, unique: true, name: "idx_rp_step_up_states_state_digest")
    add_index(:rp_step_up_states, :expires_at, name: "idx_rp_step_up_states_expires_at")
    add_check_constraint(:rp_step_up_states, "realm = 'APP'", name: "chk_rp_step_up_states_realm")

    create_table(:rp_step_up_state_transitions) do |t|
      t.references(:owner, null: false, index: false, foreign_key: { to_table: :rp_step_up_states, on_delete: :cascade })
      t.references(:from_state, null: false, foreign_key: { to_table: :rp_step_up_state_statuses })
      t.references(:to_state, null: false, foreign_key: { to_table: :rp_step_up_state_statuses })
      t.string(:reason_code, null: false, limit: 64)
      t.datetime(:occurred_at, null: false)
    end
    add_index(
      :rp_step_up_state_transitions,
      %i(owner_id to_state_id),
      unique: true,
      name: "idx_rp_step_up_state_transitions_owner_to",
    )
  end

  def create_audit_outbox
    create_table(:rp_step_up_audit_outbox_delivery_states, id: :bigint)

    create_table(:rp_step_up_audit_outboxes) do |t|
      t.uuid(:event_uuid, null: false)
      t.string(:event_type, null: false, limit: 64)
      t.string(:realm, null: false, limit: 3)
      t.string(:client_id, null: false, limit: 64)
      t.string(:subject_ref, null: false, limit: 255)
      t.string(:context_ref, null: false, limit: 21)
      t.string(:reason_code, null: false, limit: 64)
      t.jsonb(:payload, null: false)
      t.datetime(:occurred_at, null: false)
      t.references(:delivery_state, null: false, foreign_key: { to_table: :rp_step_up_audit_outbox_delivery_states })
      t.timestamps(null: false)
    end
  end

  def add_audit_outbox_constraints
    add_index(:rp_step_up_audit_outboxes, :event_uuid, unique: true, name: "idx_rp_step_up_audit_outboxes_event_uuid")
    add_index(:rp_step_up_audit_outboxes, :delivery_state_id, name: "idx_rp_step_up_audit_outboxes_delivery")
    add_index(
      :rp_step_up_audit_outboxes,
      %i(realm client_id context_ref reason_code),
      unique: true,
      where: "event_type = 'step_up.attempt_rejected'",
      name: "idx_rp_step_up_audit_outboxes_rejected",
    )
    add_check_constraint(
      :rp_step_up_audit_outboxes,
      "event_type IN ('step_up.requested', 'step_up.committed', 'step_up.installed', 'step_up.cancelled', 'step_up.expired', 'step_up.failed', 'step_up.refused', 'step_up.indeterminate', 'step_up.attempt_rejected')",
      name: "chk_rp_step_up_audit_event",
    )
    add_check_constraint(:rp_step_up_audit_outboxes, "realm = 'APP'", name: "chk_rp_step_up_audit_realm")
    add_check_constraint(
      :rp_step_up_audit_outboxes,
      <<~SQL.squish,
        jsonb_typeof(payload) = 'object' AND
        ((event_type = 'step_up.requested' AND payload ?& ARRAY['rp_state_ref', 'return_target_kind']::text[] AND payload - ARRAY['rp_state_ref', 'return_target_kind']::text[] = '{}'::jsonb) OR
         (event_type = 'step_up.committed' AND payload ?& ARRAY['op_context_ref', 'grant_ref', 'verified_method', 'auth_time']::text[] AND payload - ARRAY['op_context_ref', 'grant_ref', 'verified_method', 'auth_time']::text[] = '{}'::jsonb) OR
         (event_type = 'step_up.installed' AND payload ?& ARRAY['rp_state_ref', 'grant_ref', 'installed_generation']::text[] AND payload - ARRAY['rp_state_ref', 'grant_ref', 'installed_generation']::text[] = '{}'::jsonb) OR
         ((event_type IN ('step_up.cancelled', 'step_up.expired')) AND ((payload ? 'op_context_ref') <> (payload ? 'rp_state_ref')) AND payload - ARRAY['op_context_ref', 'rp_state_ref']::text[] = '{}'::jsonb) OR
         (event_type = 'step_up.failed' AND payload ?& ARRAY['op_context_ref', 'failure_code']::text[] AND payload - ARRAY['op_context_ref', 'failure_code']::text[] = '{}'::jsonb) OR
         (event_type IN ('step_up.refused', 'step_up.indeterminate') AND payload ?& ARRAY['rp_state_ref', 'failure_code']::text[] AND payload - ARRAY['rp_state_ref', 'failure_code']::text[] = '{}'::jsonb) OR
         (event_type = 'step_up.attempt_rejected' AND payload ?& ARRAY['context_ref', 'rejection_code']::text[] AND payload - ARRAY['context_ref', 'rejection_code']::text[] = '{}'::jsonb))
      SQL
      name: "chk_rp_step_up_audit_payload",
    )
    add_check_constraint(:rp_step_up_audit_outboxes, "length(reason_code) > 0", name: "chk_rp_step_up_audit_reason")
  end

  def create_audit_attempts
    create_table(:rp_step_up_audit_outbox_attempts) do |t|
      t.references(:outbox, null: false, foreign_key: { to_table: :rp_step_up_audit_outboxes, on_delete: :cascade })
      t.integer(:attempt_number, null: false)
      t.datetime(:attempted_at, null: false)
      t.string(:outcome, null: false, limit: 16)
      t.string(:failure_code, null: false, limit: 64)
    end
    add_index(
      :rp_step_up_audit_outbox_attempts,
      %i(outbox_id attempt_number),
      unique: true,
      name: "idx_rp_step_up_audit_attempts_number",
    )
    add_index(
      :rp_step_up_audit_outbox_attempts,
      :outbox_id,
      unique: true,
      where: "outcome = 'delivered'",
      name: "idx_rp_step_up_audit_attempts_delivered",
    )
    add_check_constraint(:rp_step_up_audit_outbox_attempts, "attempt_number > 0", name: "chk_rp_step_up_audit_attempt_number")
    add_check_constraint(
      :rp_step_up_audit_outbox_attempts,
      "outcome IN ('delivered', 'failed')",
      name: "chk_rp_step_up_audit_attempt_outcome",
    )
    add_check_constraint(:rp_step_up_audit_outbox_attempts, "length(failure_code) > 0", name: "chk_rp_step_up_audit_attempt_failure")
  end
end
