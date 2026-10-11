# frozen_string_literal: true

class AddAvatarTransferSourceOwnershipPeriod < ActiveRecord::Migration[8.2]
  DETAILS = %i(
    avatar_enterprise_to_enterprise_transfer_details
    avatar_enterprise_to_bureau_transfer_details
    avatar_bureau_to_enterprise_transfer_details
    avatar_bureau_to_bureau_transfer_details
  ).freeze

  disable_ddl_transaction!

  def up
    DETAILS.each do |table|
      safety_assured do
        add_reference(
          table,
          :source_ownership_period,
          null: true,
          index: { algorithm: :concurrently },
          foreign_key: false,
        )
      end
    end
  end

  def down
    DETAILS.each do |table|
      remove_index(table, :source_ownership_period_id)
      remove_column(table, :source_ownership_period_id)
    end
  end
end
