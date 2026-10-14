# frozen_string_literal: true
class AddSelectorActivationToOperatorSignInCycles < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column :operator_sign_in_cycles, :selected_region_id, :bigint, if_not_exists: true
    add_column :operator_sign_in_cycles, :selected_persona_id, :bigint, if_not_exists: true
    add_column :operator_sign_in_cycles, :selector_completed_at, :datetime, if_not_exists: true
    add_column :operator_sign_in_cycles, :session_issued_at, :datetime, if_not_exists: true

    add_index :operator_sign_in_cycles, :selected_region_id, if_not_exists: true, algorithm: :concurrently
    add_index :operator_sign_in_cycles, :selected_persona_id, if_not_exists: true, algorithm: :concurrently
  end
end
