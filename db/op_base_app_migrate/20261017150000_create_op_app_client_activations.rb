# frozen_string_literal: true

# R5-WU19 activation authority (one.md 8, R5-WU19): the app OP admits an exact RP client only for
# the current contract epoch, and only after an audited enable. No row means closed.
class CreateOpAppClientActivations < ActiveRecord::Migration[8.2]
  public

  def change
    create_table(:op_client_activations) do |t|
      t.string(:client_id, limit: 64, null: false)
      t.bigint(:contract_epoch, null: false)
      t.boolean(:enabled, null: false, default: false)
      t.datetime(:changed_at, null: false)
      t.string(:actor_ref, limit: 255, null: false)
      t.string(:audit_ref, limit: 255, null: false)
      t.string(:source_manifest_digest, limit: 64, null: false)
      t.timestamps
    end
    add_index(
      :op_client_activations, %i(client_id contract_epoch), unique: true,
                                                            name: "idx_op_app_client_activations_client_epoch",
    )
    add_check_constraint(
      :op_client_activations, "contract_epoch > 0",
      name: "chk_op_app_client_activations_epoch_positive",
    )
    add_check_constraint(
      :op_client_activations, "source_manifest_digest ~ '^[0-9a-f]{64}$'",
      name: "chk_op_app_client_activations_digest_format",
    )
  end
end
