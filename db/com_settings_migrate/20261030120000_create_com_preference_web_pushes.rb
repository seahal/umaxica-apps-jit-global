# frozen_string_literal: true

class CreateComPreferenceWebPushes < ActiveRecord::Migration[8.2]
  def change
    create_table(:com_preference_web_push_options)
    add_check_constraint(
      :com_preference_web_push_options, "id IN (0, 1)",
      name: "com_preference_web_push_options_closed",
    )

    create_table(:com_preference_web_pushes) do |t|
      t.references(:preference, null: false, foreign_key: { to_table: :com_preferences }, index: { unique: true })
      t.references(:option, null: false, foreign_key: { to_table: :com_preference_web_push_options })
      t.timestamps
    end
  end
end
