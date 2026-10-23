# frozen_string_literal: true

# WU-17 (D-35): RP sessions no longer record the OP contract epoch.
class RemoveContractEpochRpBaseApp < ActiveRecord::Migration[8.2]
  def up
    remove_check_constraint(:rp_sessions, name: "chk_rp_base_app_sessions_shape")
    safety_assured { remove_column(:rp_sessions, :contract_epoch) }
    add_check_constraint(:rp_sessions, "installed_generation >= 0", name: "chk_rp_base_app_sessions_shape", validate: false)
  end

  def down
    remove_check_constraint(:rp_sessions, name: "chk_rp_base_app_sessions_shape")
    add_column(:rp_sessions, :contract_epoch, :bigint, null: false, default: 1)
    add_check_constraint(
      :rp_sessions, "installed_generation >= 0 AND contract_epoch >= 1", name: "chk_rp_base_app_sessions_shape",
    )
  end
end
