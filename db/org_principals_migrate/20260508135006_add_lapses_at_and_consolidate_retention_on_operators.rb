# frozen_string_literal: true
class AddLapsesAtAndConsolidateRetentionOnOperators < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      add_column :staffs, :discarded_at, :datetime, null: false, default: -> { "'infinity'" } unless column_exists?(:staffs, :discarded_at)
      if column_exists?(:staffs, :deletable_at) && !column_exists?(:staffs, :purged_at)
        rename_column :staffs, :deletable_at, :purged_at
      elsif !column_exists?(:staffs, :purged_at)
        add_column :staffs, :purged_at, :datetime, null: false, default: -> { "'infinity'" }
      end
    
      reversible do |dir|
        dir.up do
          execute("UPDATE staffs SET shreddable_at = LEAST(purged_at, shreddable_at) WHERE shreddable_at IS NOT NULL;") if column_exists?(:staffs, :shreddable_at)
        end
      end
      remove_column :staffs, :shreddable_at, :datetime, if_exists: true

      reversible do |dir|
        dir.up do
          execute("ALTER TABLE staffs ADD CONSTRAINT chk_staffs_retention_order CHECK (discarded_at <= purged_at) NOT VALID;")
          execute("ALTER TABLE staffs VALIDATE CONSTRAINT chk_staffs_retention_order;")
        end
        dir.down do
          execute("ALTER TABLE staffs DROP CONSTRAINT IF EXISTS chk_staffs_retention_order;")
        end
      end
    end
  end
end
