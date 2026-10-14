# frozen_string_literal: true
class AddMissingPurgeAtToCredentials < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      tables = %w[
        user_verifications staff_verifications customer_verifications
        user_authorization_codes staff_authorization_codes customer_authorization_codes
        user_reauth_sessions staff_reauth_sessions customer_reauth_sessions
        user_secrets staff_secrets customer_secrets
      ]
      tables.each do |t|
        if table_exists?(t)
          add_column t, :purged_at, :datetime, null: false, default: -> { "'infinity'" } unless column_exists?(t, :purged_at) || column_exists?(t, :deletable_at)
          
          reversible do |dir|
            dir.up do
              if column_exists?(t, :discarded_at) && column_exists?(t, :purged_at)
                unless check_constraint_exists?(t, name: "chk_#{t}_retention_order")
                  execute("ALTER TABLE #{t} ADD CONSTRAINT chk_#{t}_retention_order CHECK (discarded_at <= purged_at) NOT VALID;")
                end
                execute("ALTER TABLE #{t} VALIDATE CONSTRAINT chk_#{t}_retention_order;")
              end
            end
          end
        end
      end
    end
  end
end
