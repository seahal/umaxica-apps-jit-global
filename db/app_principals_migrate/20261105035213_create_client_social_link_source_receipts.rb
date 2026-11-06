# frozen_string_literal: true

class CreateClientSocialLinkSourceReceipts < ActiveRecord::Migration[8.2]
  def change
    create_table(:client_social_link_source_receipts) do |t|
      t.string(:admission_ref, null: false, limit: 21)
      t.string(:actor_ref, null: false, limit: 64)
      t.string(:provider, null: false, limit: 16)
      t.bigint(:client_external_identity_id, null: false)
      t.timestamptz(:committed_at, null: false)
    end

    add_index(:client_social_link_source_receipts, :admission_ref, unique: true,
              name: "idx_client_social_link_receipt_admission")
    add_index(:client_social_link_source_receipts, :client_external_identity_id,
              name: "idx_client_social_link_receipt_identity")
    add_check_constraint(:client_social_link_source_receipts,
                         "admission_ref ~ '^[A-Za-z0-9_-]{21}$' AND provider IN ('google', 'apple')",
                         name: "client_social_link_receipt_values")
    add_foreign_key(:client_social_link_source_receipts, :client_external_identities,
                    column: :client_external_identity_id, on_delete: :restrict, validate: false)
  end
end
