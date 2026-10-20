# frozen_string_literal: true

class ValidateNanoidPublicIdLengthRpTechOrg < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:rp_principals, name: "chk_rp_principals_pid")
    validate_check_constraint(:rp_refresh_attempts, name: "chk_rp_refresh_attempts_pid")
    validate_check_constraint(:rp_sessions, name: "chk_rp_sessions_pid")
  end
end
