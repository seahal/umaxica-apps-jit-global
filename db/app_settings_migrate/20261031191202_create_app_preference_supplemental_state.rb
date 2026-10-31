# frozen_string_literal: true

class CreateAppPreferenceSupplementalState < ActiveRecord::Migration[8.2]
  def change
    create_table(:app_preference_consent_receipts) do |t|
      t.references(:preference, null: false, foreign_key: { to_table: :app_preferences }, index: { unique: true })
      t.uuid(:version, null: false)
      t.datetime(:recorded_at, null: false)
      t.timestamps
    end

    create_table(:app_preference_browser_bindings) do |t|
      t.references(:preference, null: false, foreign_key: { to_table: :app_preferences }, index: { unique: true })
      t.string(:digest, null: false, limit: 64)
      t.timestamps
    end
    add_check_constraint(
      :app_preference_browser_bindings, "digest ~ '^[0-9a-f]{64}$'",
      name: "app_preference_browser_bindings_digest_format",
    )

    create_table(:app_preference_web_push_options)
    add_check_constraint(
      :app_preference_web_push_options, "id IN (0, 1)",
      name: "app_preference_web_push_options_closed",
    )

    create_table(:app_preference_web_pushes) do |t|
      t.references(:preference, null: false, foreign_key: { to_table: :app_preferences }, index: { unique: true })
      t.references(:option, null: false, foreign_key: { to_table: :app_preference_web_push_options })
      t.timestamps
    end
  end
end
