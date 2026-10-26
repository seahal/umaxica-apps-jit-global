# frozen_string_literal: true

# WU-10 (D-25): standard refresh rotation has no RP delivery-recovery attempt record. The drop is
# authorized by D-168 (destructive changes) and D-159 (database reset, no data to preserve). The
# down path restores the empty table shape only; dropped rows are not recoverable.
class DropRpRefreshAttemptsRpCoreOrg < ActiveRecord::Migration[8.2]
  def up
    drop_table(:rp_refresh_attempts)
  end

  def down
    create_table(:rp_refresh_attempts) do |t|
      t.string(:public_id, limit: 21, null: false)
      t.bigint(:session_id, null: false)
      t.binary(:input_hmac, null: false)
      t.bigint(:expected_installed_generation, null: false)
      t.datetime(:dispatched_at)
      t.datetime(:uncertain_at)
      t.datetime(:installed_at)
      t.datetime(:expires_at, null: false)
      t.timestamps
    end
    add_index(:rp_refresh_attempts, :public_id, unique: true, name: "idx_rp_core_org_refresh_attempts_public_id")
    add_index(:rp_refresh_attempts, :expires_at, name: "idx_rp_core_org_refresh_attempts_expiry")
    add_index(:rp_refresh_attempts, :session_id)
    add_check_constraint(:rp_refresh_attempts, "char_length(public_id) = 21", name: "chk_rp_refresh_attempts_pid")
    add_check_constraint(
      :rp_refresh_attempts, "expected_installed_generation >= 0", name: "chk_rp_core_org_refresh_attempts_shape",
    )
    add_foreign_key(:rp_refresh_attempts, :rp_sessions, column: :session_id, name: "fk_rp_core_org_refresh_attempts_session")
  end
end
