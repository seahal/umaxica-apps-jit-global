# frozen_string_literal: true

class CreateOperatorPasskeyCeremonyCandidates < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  public

  def change
    create_table(:operator_passkey_ceremony_candidates) do |t|
      t.string(:ref, null: false)
      t.string(:digest, null: false)
      t.string(:surface, null: false)
      t.string(:actor_ref, null: false)
      t.string(:session_ref, null: false)
      t.string(:step_up_ceremony_transaction_ref, null: false)
      t.string(:webauthn_id, null: false)
      t.text(:public_key, null: false)
      t.bigint(:sign_count, null: false, default: 0)
      t.string(:description, null: false)
      t.jsonb(:transports, null: false, default: [])
      t.jsonb(:metadata, null: false, default: {})
      t.timestamptz(:expires_at, null: false)
      t.timestamptz(:consumed_at)
      t.bigint(:lock_version, null: false, default: 0)
      t.timestamps(type: :timestamptz)

      t.index(:ref, unique: true)
      t.index(:step_up_ceremony_transaction_ref, unique: true)
      t.index(:expires_at)
    end

    add_foreign_key(
      :operator_passkey_ceremony_candidates, :operator_step_up_ceremony_transactions,
      column: :step_up_ceremony_transaction_ref, primary_key: :transaction_id, on_delete: :restrict,
      validate: false,
    )
    validate_foreign_key(:operator_passkey_ceremony_candidates, :operator_step_up_ceremony_transactions)
  end
end
