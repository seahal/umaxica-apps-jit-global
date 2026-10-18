# frozen_string_literal: true

class AddNotNullCheckToVisitorPreferencePublicId < ActiveRecord::Migration[8.2]
  TABLE = :visitor_preferences

  def change
    add_check_constraint(
      TABLE,
      "public_id IS NOT NULL",
      name: "#{TABLE}_public_id_not_null",
      validate: false,
    )
    add_check_constraint(
      TABLE,
      "public_id IS NULL OR public_id !~ '^[[:space:]]*$'",
      name: "#{TABLE}_public_id_nonblank",
      validate: false,
    )
  end
end
