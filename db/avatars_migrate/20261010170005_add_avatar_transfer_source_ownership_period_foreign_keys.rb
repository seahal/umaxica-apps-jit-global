# frozen_string_literal: true

class AddAvatarTransferSourceOwnershipPeriodForeignKeys < ActiveRecord::Migration[8.2]
  DETAILS = {
    avatar_enterprise_to_enterprise_transfer_details: :avatar_enterprise_ownership_periods,
    avatar_enterprise_to_bureau_transfer_details: :avatar_enterprise_ownership_periods,
    avatar_bureau_to_enterprise_transfer_details: :avatar_bureau_ownership_periods,
    avatar_bureau_to_bureau_transfer_details: :avatar_bureau_ownership_periods,
  }.freeze

  def up
    DETAILS.each do |table, period_table|
      add_foreign_key(
        table,
        period_table,
        column: :source_ownership_period_id,
        on_delete: :restrict,
        validate: false,
      )
    end
  end

  def down
    DETAILS.each do |table, period_table|
      remove_foreign_key(table, column: :source_ownership_period_id, to_table: period_table)
    end
  end
end
