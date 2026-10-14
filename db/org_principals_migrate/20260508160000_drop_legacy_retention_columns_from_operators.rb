# frozen_string_literal: true
class DropLegacyRetentionColumnsFromOperators < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      remove_index :operators, :shreddable_at, if_exists: true
      remove_column :operators, :shreddable_at, :datetime, if_exists: true
    end
  end
end
