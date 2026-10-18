# frozen_string_literal: true
class AddCheckpointVersionToClientSignUpCycles < ActiveRecord::Migration[8.2]
  def change
    add_column :client_sign_up_cycles, :checkpoint_version, :integer, null: false, default: 0 unless
      column_exists?(:client_sign_up_cycles, :checkpoint_version)
  end
end
