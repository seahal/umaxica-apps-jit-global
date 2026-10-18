# typed: false
# frozen_string_literal: true

class CreateOperatorStepUpCeremonyTransactions < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    create_table :operator_step_up_ceremony_transactions, if_not_exists: true do |t|
      t.string :transaction_id, null: false
      t.string :surface, null: false
      t.string :actor_ref, null: false
      t.string :session_ref, null: false
      t.string :required_scope, null: false
      t.string :required_aal, null: false
      t.text :allowed_methods, null: false
      t.string :resource_ref
      t.string :return_to
      t.string :status, null: false, default: "pending"
      t.string :grant_jti, null: false
      t.string :result_jti
      t.string :method
      t.string :aal
      t.datetime :verified_at
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.bigint :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :operator_step_up_ceremony_transactions, :transaction_id, unique: true,
                                                                         algorithm: :concurrently,
                                                                         if_not_exists: true
    add_index :operator_step_up_ceremony_transactions, :grant_jti, unique: true,
                                                                    algorithm: :concurrently,
                                                                    if_not_exists: true
    add_index :operator_step_up_ceremony_transactions, :result_jti, unique: true,
                                                                     where: "result_jti IS NOT NULL",
                                                                     algorithm: :concurrently,
                                                                     if_not_exists: true
    add_index :operator_step_up_ceremony_transactions, :expires_at, algorithm: :concurrently, if_not_exists: true
    add_index :operator_step_up_ceremony_transactions, %i(actor_ref session_ref), algorithm: :concurrently,
                                                                                 if_not_exists: true
    add_index :operator_step_up_ceremony_transactions, :required_scope, algorithm: :concurrently, if_not_exists: true
  end
end
