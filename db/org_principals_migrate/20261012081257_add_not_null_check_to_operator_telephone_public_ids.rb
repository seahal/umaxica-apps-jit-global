# frozen_string_literal: true

class AddNotNullCheckToOperatorTelephonePublicIds < ActiveRecord::Migration[8.2]
  NOT_NULL_CONSTRAINT = "operator_telephones_public_id_not_null"

  def change
    # The operational NULL-only backfill must complete before this constraint is validated.
    # NOT VALID keeps the additive schema step short and lets the next migration prove the
    # existing rows before changing the column metadata.
    add_check_constraint(
      :operator_telephones,
      "public_id IS NOT NULL",
      name: NOT_NULL_CONSTRAINT,
      validate: false,
    )
  end
end
