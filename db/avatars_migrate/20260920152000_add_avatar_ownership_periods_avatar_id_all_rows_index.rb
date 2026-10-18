# frozen_string_literal: true

class AddAvatarOwnershipPeriodsAvatarIdAllRowsIndex < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  INDEX_NAME = "idx_avatar_ownership_periods_avatar_id_all_rows"

  def up
    return if equivalent_index_exists?

    add_index(
      :avatar_ownership_periods,
      :avatar_id,
      name: INDEX_NAME,
      algorithm: :concurrently,
    )
  end

  def down
    remove_index(
      :avatar_ownership_periods,
      name: INDEX_NAME,
      algorithm: :concurrently,
      if_exists: true,
    )
  end

  private

  def equivalent_index_exists?
    connection.indexes(:avatar_ownership_periods).any? do |index|
      index.valid && index.columns == ["avatar_id"] && !index.unique && index.where.blank?
    end
  end
end
