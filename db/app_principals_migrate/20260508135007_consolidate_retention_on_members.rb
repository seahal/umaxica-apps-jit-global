# frozen_string_literal: true
class ConsolidateRetentionOnMembers < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      add_column :members, :discarded_at, :datetime, null: false, default: -> { "'infinity'" } unless column_exists?(:members, :discarded_at)
      rename_column :members, :shreddable_at, :purged_at if column_exists?(:members, :shreddable_at)
    end
  end
end
