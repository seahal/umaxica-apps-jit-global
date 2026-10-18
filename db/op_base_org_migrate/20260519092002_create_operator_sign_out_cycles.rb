# frozen_string_literal: true
class CreateOperatorSignOutCycles < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      create_table :operator_sign_out_cycle_statuses do |_t|
      end

      create_table :operator_sign_out_cycle_kinds do |_t|
      end

      create_table :operator_sign_out_cycles do |t|
        t.string :public_id, limit: 21, null: false
        t.bigint :principal_id
        t.bigint :token_id
        t.bigint :status_id, null: false, default: 10
        t.bigint :kind_id, null: false, default: 0
        t.string :refresh_token_family_id
        t.datetime :requested_at, null: false
        t.datetime :access_discarded_at
        t.datetime :logically_revoked_at
        t.datetime :access_expires_at, null: false
        t.datetime :refresh_expires_at, null: false
        t.datetime :completed_at
        t.datetime :failed_at
        t.text :return_to
        t.string :nonce_digest
        t.datetime :discarded_at, null: false, default: Float::INFINITY
        t.datetime :purged_at, null: false, default: Float::INFINITY
        t.timestamps

        t.index :public_id, unique: true
        t.index :principal_id
        t.index :token_id
        t.index :status_id
        t.index :kind_id
        t.index :refresh_token_family_id
        t.index :access_expires_at
        t.index :refresh_expires_at
        t.index :discarded_at
        t.index :purged_at
        t.check_constraint "discarded_at <= purged_at", name: "chk_operator_sign_out_cycles_retention_order"
        t.check_constraint "access_expires_at <= refresh_expires_at",
                           name: "chk_operator_sign_out_cycles_token_expiry_order"
      end
    end

    add_foreign_key :operator_sign_out_cycles, :operator_sign_out_cycle_statuses, column: :status_id, validate: false
    add_foreign_key :operator_sign_out_cycles, :operator_sign_out_cycle_kinds, column: :kind_id, validate: false
    add_foreign_key :operator_sign_out_cycles, :staff_tokens, column: :token_id, on_delete: :cascade, validate: false
  end
end
