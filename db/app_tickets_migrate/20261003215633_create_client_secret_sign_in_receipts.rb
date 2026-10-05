# frozen_string_literal: true

class CreateClientSecretSignInReceipts < ActiveRecord::Migration[8.2]
  public

  def change
    create_table(:client_secret_sign_in_receipts) do |t|
      t.uuid(:operation_id, null: false)
      t.string(:credential_ref, limit: 21, null: false)
      t.string(:client_ref, limit: 21, null: false)
      t.references(:sign_in_flow, null: false, foreign_key: { to_table: :client_sign_in_flows })
      t.string(:root_token_ref, limit: 21, null: false)
      t.datetime(:committed_at, null: false)
      t.datetime(:discard_at, null: false, default: Float::INFINITY)
      t.datetime(:purge_eligible_at, null: false, default: Float::INFINITY)
      t.timestamps
    end
    add_index(:client_secret_sign_in_receipts, :operation_id, unique: true)
    add_index(:client_secret_sign_in_receipts, :credential_ref, unique: true)
    add_index(:client_secret_sign_in_receipts, :root_token_ref, unique: true)
  end
end
