# frozen_string_literal: true
class ConsolidateRetentionOnStaffCredentials < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      ["staff_tokens", "staff_verifications", "staff_authorization_codes", "staff_reauth_sessions", "staff_secrets"].each do |t|
        if table_exists?(t)
          add_column t, :discarded_at, :datetime, null: false, default: -> { "'infinity'" } unless column_exists?(t, :discarded_at)
          rename_column t, :deletable_at, :purged_at if column_exists?(t, :deletable_at)
          
          reversible do |dir|
            dir.up do
              execute("UPDATE #{t} SET discarded_at = LEAST(discarded_at, refresh_expires_at) WHERE refresh_expires_at IS NOT NULL;") if column_exists?(t, :refresh_expires_at)
              execute("UPDATE #{t} SET discarded_at = LEAST(discarded_at, revoked_at) WHERE revoked_at IS NOT NULL;") if column_exists?(t, :revoked_at)
              execute("UPDATE #{t} SET discarded_at = LEAST(discarded_at, expires_at) WHERE expires_at IS NOT NULL;") if column_exists?(t, :expires_at)
            end
          end
          
          remove_column t, :refresh_expires_at, :datetime, if_exists: true
          remove_column t, :revoked_at, :datetime, if_exists: true
          remove_column t, :expired_at, :datetime, if_exists: true
          remove_column t, :expires_at, :datetime, if_exists: true
        end
      end
    end
  end
end
