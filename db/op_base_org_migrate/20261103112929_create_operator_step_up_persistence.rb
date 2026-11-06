# frozen_string_literal: true

class CreateOperatorStepUpPersistence < ActiveRecord::Migration[8.2]
  def change
    create_context_tables
    create_commit_facts
    create_audit_outbox
    add_audit_outbox_constraints
    create_audit_attempts
  end

  private

  def create_context_tables
    create_table(:operator_step_up_context_states, id: :bigint)

    create_table(:operator_step_up_contexts) do |t|
      t.string(:public_id, null: false, limit: 21)
      t.references(
        :oidc_authorization_transaction,
        null: false,
        index: { unique: true },
        foreign_key: { to_table: :operator_oidc_authorization_transactions, on_delete: :cascade },
      )
      t.references(:grant, null: false, foreign_key: { to_table: :op_org_grants })
      t.string(:bound_subject, null: false, limit: 255)
      t.string(:requested_acr, null: false, limit: 255)
      t.references(:state, null: false, foreign_key: { to_table: :operator_step_up_context_states })
      t.datetime(:expires_at, null: false)
      t.integer(:lock_version, null: false, default: 0)
      t.timestamps(null: false)
    end

    add_index(:operator_step_up_contexts, :public_id, unique: true, name: "idx_operator_step_up_contexts_public_id")
    add_check_constraint(
      :operator_step_up_contexts,
      "requested_acr = 'https://visa.umaxica.app/acr/reauthentication'",
      name: "chk_operator_step_up_contexts_acr",
    )

    create_table(:operator_step_up_context_transitions) do |t|
      t.references(
        :owner,
        null: false,
        index: false,
        foreign_key: { to_table: :operator_step_up_contexts, on_delete: :cascade },
      )
      t.references(:from_state, null: false, foreign_key: { to_table: :operator_step_up_context_states })
      t.references(:to_state, null: false, foreign_key: { to_table: :operator_step_up_context_states })
      t.string(:reason_code, null: false, limit: 64)
      t.datetime(:occurred_at, null: false)
    end
    add_index(
      :operator_step_up_context_transitions,
      %i(owner_id to_state_id),
      unique: true,
      name: "idx_operator_step_up_context_transitions_owner_to",
    )
  end

  def create_commit_facts
    create_table(:operator_step_up_commits) do |t|
      t.references(:grant, null: false, foreign_key: { to_table: :op_org_grants })
      t.references(:root_token, null: false, foreign_key: { to_table: :operator_tokens, on_delete: :cascade })
      t.string(:context_ref, null: false, limit: 21)
      t.string(:verified_method, null: false, limit: 16)
      t.datetime(:committed_at, null: false)
    end
    add_index(:operator_step_up_commits, :context_ref, unique: true, name: "idx_operator_step_up_commits_context_ref")
    add_index(:operator_step_up_commits, %i(root_token_id committed_at), name: "idx_operator_step_up_commits_root_time")
    add_check_constraint(
      :operator_step_up_commits,
      "verified_method IN ('passkey', 'totp', 'email_otp')",
      name: "chk_operator_step_up_commits_method",
    )
  end

  def create_audit_outbox
    create_table(:operator_step_up_audit_outbox_delivery_states, id: :bigint)

    create_table(:operator_step_up_audit_outboxes) do |t|
      t.uuid(:event_uuid, null: false)
      t.string(:event_type, null: false, limit: 64)
      t.string(:realm, null: false, limit: 3)
      t.string(:client_id, null: false)
      t.string(:subject_ref, null: false, limit: 255)
      t.string(:context_ref, null: false, limit: 21)
      t.string(:reason_code, null: false, limit: 64)
      t.jsonb(:payload, null: false)
      t.datetime(:occurred_at, null: false)
      t.references(:delivery_state, null: false, foreign_key: { to_table: :operator_step_up_audit_outbox_delivery_states })
      t.timestamps(null: false)
    end
  end

  def add_audit_outbox_constraints
    add_index(:operator_step_up_audit_outboxes, :event_uuid, unique: true, name: "idx_operator_step_up_audit_outboxes_event_uuid")
    add_index(:operator_step_up_audit_outboxes, :delivery_state_id, name: "idx_operator_step_up_audit_outboxes_delivery")
    add_index(
      :operator_step_up_audit_outboxes,
      %i(realm client_id context_ref reason_code),
      unique: true,
      where: "event_type = 'step_up.attempt_rejected'",
      name: "idx_operator_step_up_audit_outboxes_rejected",
    )
    add_check_constraint(
      :operator_step_up_audit_outboxes,
      "event_type IN ('step_up.requested', 'step_up.committed', 'step_up.installed', 'step_up.cancelled', 'step_up.expired', 'step_up.failed', 'step_up.refused', 'step_up.indeterminate', 'step_up.attempt_rejected')",
      name: "chk_operator_step_up_audit_event",
    )
    add_check_constraint(:operator_step_up_audit_outboxes, "realm = 'ORG'", name: "chk_operator_step_up_audit_realm")
    add_check_constraint(
      :operator_step_up_audit_outboxes,
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
      name: "chk_operator_step_up_audit_payload",
    )
    add_check_constraint(:operator_step_up_audit_outboxes, "length(reason_code) > 0", name: "chk_operator_step_up_audit_reason")
  end

  def create_audit_attempts
    create_table(:operator_step_up_audit_outbox_attempts) do |t|
      t.references(:outbox, null: false, foreign_key: { to_table: :operator_step_up_audit_outboxes, on_delete: :cascade })
      t.integer(:attempt_number, null: false)
      t.datetime(:attempted_at, null: false)
      t.string(:outcome, null: false, limit: 16)
      t.string(:failure_code, null: false, limit: 64)
    end
    add_index(
      :operator_step_up_audit_outbox_attempts,
      %i(outbox_id attempt_number),
      unique: true,
      name: "idx_operator_step_up_audit_attempts_number",
    )
    add_index(
      :operator_step_up_audit_outbox_attempts,
      :outbox_id,
      unique: true,
      where: "outcome = 'delivered'",
      name: "idx_operator_step_up_audit_attempts_delivered",
    )
    add_check_constraint(
      :operator_step_up_audit_outbox_attempts,
      "attempt_number > 0",
      name: "chk_operator_step_up_audit_attempt_number",
    )
    add_check_constraint(
      :operator_step_up_audit_outbox_attempts,
      "outcome IN ('delivered', 'failed')",
      name: "chk_operator_step_up_audit_attempt_outcome",
    )
    add_check_constraint(
      :operator_step_up_audit_outbox_attempts,
      "length(failure_code) > 0",
      name: "chk_operator_step_up_audit_attempt_failure",
    )
  end
end
