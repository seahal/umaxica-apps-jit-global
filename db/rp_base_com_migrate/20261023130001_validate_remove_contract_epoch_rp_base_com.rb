# frozen_string_literal: true

class ValidateRemoveContractEpochRpBaseCom < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:rp_sessions, name: "chk_rp_base_com_sessions_shape")
  end
end
