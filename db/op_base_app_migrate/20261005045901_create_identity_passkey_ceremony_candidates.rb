# frozen_string_literal: true

# Holds a Passkey that Auth has verified but Base has not yet turned into a credential. The row
# belongs to exactly one step-up transaction; Base consumes it when it creates the credential.
# Additive: rolling back drops a table that only unfinished registrations use.
class CreateIdentityPasskeyCeremonyCandidates < ActiveRecord::Migration[8.2]
  # The foreign key is added unvalidated and validated afterwards, so the referenced table is not
  # write-locked while existing rows are checked; the two steps cannot share one DDL transaction.
  disable_ddl_transaction!

  public

  def change
    create_table(:identity_passkey_ceremony_candidates) do |t|
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
      # One verified Passkey per registration permission.
      t.index(:step_up_ceremony_transaction_ref, unique: true)
      t.index(:expires_at)
    end

    add_foreign_key(
      :identity_passkey_ceremony_candidates, :client_step_up_ceremony_transactions,
      column: :step_up_ceremony_transaction_ref, primary_key: :transaction_id, on_delete: :restrict,
      validate: false,
    )
    validate_foreign_key(:identity_passkey_ceremony_candidates, :client_step_up_ceremony_transactions)
  end
end
