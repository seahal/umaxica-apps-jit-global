# typed: false
# frozen_string_literal: true

# Feature flag storage for Flipper. Mirrors `rails generate flipper:active_record`
# with a text `value` column, which the adapter requires for JSON gates.
class CreateFlipperTables < ActiveRecord::Migration[8.2]
  def up
    create_table(:flipper_features) do |t|
      t.string(:key, null: false)
      t.timestamps(null: false)
    end
    add_index(:flipper_features, :key, unique: true)

    create_table(:flipper_gates) do |t|
      t.string(:feature_key, null: false)
      t.string(:key, null: false)
      t.text(:value)
      t.timestamps(null: false)
    end
    add_index(:flipper_gates, %i(feature_key key value), unique: true)
  end

  def down
    drop_table(:flipper_gates)
    drop_table(:flipper_features)
  end
end
