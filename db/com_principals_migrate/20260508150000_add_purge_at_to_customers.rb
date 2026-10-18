# frozen_string_literal: true
class AddPurgeAtToCustomers < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      t = 'customers'
      if table_exists?(t)
        add_column t, :discarded_at, :datetime, null: false, default: -> { "'infinity'" } unless column_exists?(t, :discarded_at)
        rename_column t, :deletable_at, :purged_at if column_exists?(t, :deletable_at)
        
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
            if column_exists?(t, :discarded_at) && column_exists?(t, :purged_at)
              unless check_constraint_exists?(t, name: "chk_customers_retention_order")
                execute("ALTER TABLE customers ADD CONSTRAINT chk_customers_retention_order CHECK (discarded_at <= purged_at) NOT VALID;")
              end
              execute("ALTER TABLE customers VALIDATE CONSTRAINT chk_customers_retention_order;")
            end
          end
        end
      end
    end
  end
end
