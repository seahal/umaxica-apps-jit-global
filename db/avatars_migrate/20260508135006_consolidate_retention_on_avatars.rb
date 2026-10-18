# frozen_string_literal: true
class ConsolidateRetentionOnAvatars < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      add_column :avatars, :discarded_at, :datetime, null: false, default: -> { "'infinity'" } unless column_exists?(:avatars, :discarded_at)
      rename_column :avatars, :shreddable_at, :purged_at if column_exists?(:avatars, :shreddable_at)
    end
  end
end
