# frozen_string_literal: true
class AddLapsesAtAndConsolidateRetentionOnGuests < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      add_column :customers, :discarded_at, :datetime, null: false, default: -> { "'infinity'" } unless column_exists?(:customers, :discarded_at)
      if column_exists?(:customers, :deletable_at) && !column_exists?(:customers, :purged_at)
        rename_column :customers, :deletable_at, :purged_at
      elsif !column_exists?(:customers, :purged_at)
        add_column :customers, :purged_at, :datetime, null: false, default: -> { "'infinity'" }
      end
      
      reversible do |dir|
        dir.up do
          execute("UPDATE customers SET shreddable_at = LEAST(purged_at, shreddable_at) WHERE shreddable_at IS NOT NULL;") if column_exists?(:customers, :shreddable_at)
          execute("UPDATE customers SET scheduled_purge_at = LEAST(purged_at, scheduled_purge_at) WHERE scheduled_purge_at IS NOT NULL;") if column_exists?(:customers, :scheduled_purge_at)
        end
      end

      remove_column :customers, :shreddable_at, :datetime, if_exists: true
      remove_column :customers, :scheduled_purge_at, :datetime, if_exists: true
      
      reversible do |dir|
        dir.up do
          execute("ALTER TABLE customers ADD CONSTRAINT chk_customers_retention_order CHECK (discarded_at <= purged_at) NOT VALID;")
          execute("ALTER TABLE customers VALIDATE CONSTRAINT chk_customers_retention_order;")
        end
        dir.down do
          execute("ALTER TABLE customers DROP CONSTRAINT IF EXISTS chk_customers_retention_order;")
        end
      end
    end
  end
end
