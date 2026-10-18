# frozen_string_literal: true
class CreateOrgSignSequenceTickets < ActiveRecord::Migration[8.2]
  def change
    create_sequence_ticket_table(:org_sign_in_sequence_tickets, :staff_tokens)
    create_sequence_ticket_table(:org_sign_up_sequence_tickets, :staff_tokens)
  end

  private

  def create_sequence_ticket_table(table_name, token_table)
    create_table table_name do |t|
      t.string :public_id, limit: 21, null: false
      t.bigint :principal_id
      t.bigint :token_id
      t.string :state, null: false
      t.string :step, null: false
      t.text :return_to
      t.string :nonce_digest, null: false
      t.datetime :issued_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :completed_at
      t.datetime :discarded_at, default: ::Float::INFINITY, null: false
      t.datetime :purged_at, default: ::Float::INFINITY, null: false
      t.timestamps

      t.index :public_id, unique: true
      t.index :principal_id
      t.index :token_id
      t.index :state
      t.index :expires_at
      t.index :discarded_at
      t.check_constraint "discarded_at <= purged_at", name: "chk_#{table_name}_retention_order"
      t.check_constraint "issued_at < expires_at", name: "chk_#{table_name}_lifetime_order"
    end

    add_foreign_key table_name, token_table, column: :token_id, on_delete: :cascade, validate: false
  end
end
