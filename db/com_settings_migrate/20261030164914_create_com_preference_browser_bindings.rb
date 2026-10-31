# frozen_string_literal: true

class CreateComPreferenceBrowserBindings < ActiveRecord::Migration[8.2]
  def change
    create_table(:com_preference_browser_bindings) do |t|
      t.references(:preference, null: false, foreign_key: { to_table: :com_preferences }, index: { unique: true })
      t.string(:digest, null: false, limit: 64)
      t.timestamps
    end
    add_check_constraint(
      :com_preference_browser_bindings, "digest ~ '^[0-9a-f]{64}$'",
      name: "com_preference_browser_bindings_digest_format",
    )
  end
end
