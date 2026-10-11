# frozen_string_literal: true

class CreateAvatarPurgeDeferrals < ActiveRecord::Migration[8.2]
  def change
    create_table(:avatar_purge_deferrals) do |t|
      t.references(:avatar, null: false, index: false, foreign_key: { on_delete: :restrict })
      t.string(:reason_code, null: false, limit: 100)
      t.integer(:attempt_count, null: false, default: 0)
      t.datetime(:first_observed_at, null: false)
      t.datetime(:last_observed_at)
      t.timestamps
    end

    add_index(
      :avatar_purge_deferrals, %i(avatar_id reason_code), unique: true,
                                                          name: "idx_avatar_purge_deferrals_avatar_reason",
    )
    add_check_constraint(
      :avatar_purge_deferrals, "char_length(btrim(reason_code)) > 0",
      name: "chk_avatar_purge_deferrals_reason_nonblank",
    )
    add_check_constraint(
      :avatar_purge_deferrals, "attempt_count > 0",
      name: "chk_avatar_purge_deferrals_attempt_positive",
    )
  end
end
