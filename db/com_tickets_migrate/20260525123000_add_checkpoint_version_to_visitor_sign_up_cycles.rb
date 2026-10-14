# frozen_string_literal: true
class AddCheckpointVersionToVisitorSignUpCycles < ActiveRecord::Migration[8.2]
  def change
    add_column :visitor_sign_up_cycles, :checkpoint_version, :integer, null: false, default: 0 unless
      column_exists?(:visitor_sign_up_cycles, :checkpoint_version)
  end
end
