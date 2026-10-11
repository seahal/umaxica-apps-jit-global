# frozen_string_literal: true

class RequireAvatarTransferSourceOwnershipPeriod < ActiveRecord::Migration[8.2]
  DETAILS = %i(
    avatar_enterprise_to_enterprise_transfer_details
    avatar_enterprise_to_bureau_transfer_details
    avatar_bureau_to_enterprise_transfer_details
    avatar_bureau_to_bureau_transfer_details
  ).freeze

  def up
    DETAILS.each do |table|
      safety_assured { change_column_null(table, :source_ownership_period_id, false) }
    end
  end

  def down
    DETAILS.each do |table|
      change_column_null(table, :source_ownership_period_id, true)
    end
  end
end
