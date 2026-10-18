# frozen_string_literal: true
class AddLapsesAtAndConsolidateRetentionOnPrincipals < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      add_column :users, :discarded_at, :datetime, null: false, default: -> { "'infinity'" } unless column_exists?(:users, :discarded_at)
      if column_exists?(:users, :deletable_at) && !column_exists?(:users, :purged_at)
        rename_column :users, :deletable_at, :purged_at
      elsif !column_exists?(:users, :purged_at)
        add_column :users, :purged_at, :datetime, null: false, default: -> { "'infinity'" }
      end
      
      reversible do |dir|
        dir.up do
          execute("UPDATE users SET shreddable_at = LEAST(purged_at, shreddable_at) WHERE shreddable_at IS NOT NULL;") if column_exists?(:users, :shreddable_at)
          execute("UPDATE users SET scheduled_purge_at = LEAST(purged_at, scheduled_purge_at) WHERE scheduled_purge_at IS NOT NULL;") if column_exists?(:users, :scheduled_purge_at)
        end
      end

      remove_column :users, :shreddable_at, :datetime, if_exists: true
      remove_column :users, :scheduled_purge_at, :datetime, if_exists: true
      
      reversible do |dir|
        dir.up do
          execute("ALTER TABLE users ADD CONSTRAINT chk_users_retention_order CHECK (discarded_at <= purged_at) NOT VALID;")
          execute("ALTER TABLE users VALIDATE CONSTRAINT chk_users_retention_order;")
        end
        dir.down do
          execute("ALTER TABLE users DROP CONSTRAINT IF EXISTS chk_users_retention_order;")
        end
      end
    end
  end
end
