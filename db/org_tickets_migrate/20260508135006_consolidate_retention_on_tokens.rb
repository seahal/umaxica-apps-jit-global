# frozen_string_literal: true
class ConsolidateRetentionOnTokens < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
    tables = %w[user_tokens staff_tokens customer_tokens]
    tables.each do |t|
      if table_exists?(t)
        add_column t, :discarded_at, :datetime, null: false, default: -> { "'infinity'" } unless column_exists?(t, :discarded_at)
        rename_column t, :deletable_at, :purged_at if column_exists?(t, :deletable_at)
        
        reversible do |dir|
          dir.up do
            execute("UPDATE #{t} SET discarded_at = LEAST(discarded_at, refresh_expires_at) WHERE refresh_expires_at IS NOT NULL;") if column_exists?(t, :refresh_expires_at)
            execute("UPDATE #{t} SET discarded_at = LEAST(discarded_at, revoked_at) WHERE revoked_at IS NOT NULL;") if column_exists?(t, :revoked_at)
            # Note: expires_at is kept for tokens
          end
        end
        
        remove_column t, :refresh_expires_at, :datetime, if_exists: true
        remove_column t, :revoked_at, :datetime, if_exists: true
        remove_column t, :expired_at, :datetime, if_exists: true
      end
    end
    end
  end
end
