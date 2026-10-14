# frozen_string_literal: true
class RemoveTimestampsFromAvatarJoinTables < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
    tables = %w[avatar_role_permissions member_avatar_permissions]
    tables.each do |t|
      if table_exists?(t)
        remove_column t, :created_at, :datetime, if_exists: true
        remove_column t, :updated_at, :datetime, if_exists: true
      end
    end
    end
  end
end
