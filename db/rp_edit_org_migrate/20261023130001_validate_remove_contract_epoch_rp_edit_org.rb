# frozen_string_literal: true

class ValidateRemoveContractEpochRpEditOrg < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:rp_sessions, name: "chk_rp_edit_org_sessions_shape")
  end
end
