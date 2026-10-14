# frozen_string_literal: true
class CreateVisitorWithdrawalCycles < ActiveRecord::Migration[8.2]
  def change
    create_table :visitor_withdrawal_cycle_statuses do |_t|
    end

    create_table :visitor_withdrawal_cycles do |t|
      t.string :public_id, limit: 21, null: false
      t.bigint :visitor_id, null: false
      t.bigint :status_id, null: false, default: 10
      t.datetime :began_at, null: false
      t.datetime :completed_at
      t.datetime :failed_at
      t.datetime :discarded_at, null: false, default: Float::INFINITY
      t.datetime :purged_at, null: false, default: Float::INFINITY
      t.timestamps

      t.index :public_id, unique: true
      t.index :visitor_id
      t.index :status_id
      t.index :began_at
      t.index :completed_at
      t.index :discarded_at
      t.index :purged_at
      t.check_constraint "discarded_at <= purged_at", name: "chk_visitor_withdrawal_cycles_retention_order"
    end

    create_table :visitor_withdrawal_cycle_events do |t|
      t.bigint :visitor_withdrawal_cycle_id, null: false
      t.bigint :visitor_id, null: false
      t.bigint :from_status_id
      t.bigint :to_status_id, null: false
      t.datetime :occurred_at, null: false
      t.string :token_public_id, limit: 64, null: false, default: ""
      t.string :reason, limit: 64, null: false, default: ""
      t.jsonb :metadata, null: false, default: {}
      t.timestamps

      t.index :visitor_withdrawal_cycle_id
      t.index :visitor_id
      t.index :from_status_id
      t.index :to_status_id
      t.index :occurred_at
    end

    add_foreign_key :visitor_withdrawal_cycles, :visitors, validate: false
    add_foreign_key :visitor_withdrawal_cycles, :visitor_withdrawal_cycle_statuses, column: :status_id, validate: false
    add_foreign_key :visitor_withdrawal_cycle_events, :visitor_withdrawal_cycles, validate: false
    add_foreign_key :visitor_withdrawal_cycle_events, :visitors, validate: false
    add_foreign_key :visitor_withdrawal_cycle_events, :visitor_withdrawal_cycle_statuses,
                    column: :from_status_id, validate: false
    add_foreign_key :visitor_withdrawal_cycle_events, :visitor_withdrawal_cycle_statuses,
                    column: :to_status_id, validate: false
  end
end
