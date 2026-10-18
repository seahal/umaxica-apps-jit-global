# frozen_string_literal: true

class ValidateOperatorTelephonePublicIdNotNull < ActiveRecord::Migration[8.2]
  NONBLANK_CONSTRAINT = "operator_telephones_public_id_nonblank"
  NOT_NULL_CONSTRAINT = "operator_telephones_public_id_not_null"

  def up
    # Both checks are validated before the metadata transition; a stale NULL or blank value
    # therefore fails the migration instead of being silently repaired in schema DDL.
    validate_check_constraint(:operator_telephones, name: NONBLANK_CONSTRAINT)
    validate_check_constraint(:operator_telephones, name: NOT_NULL_CONSTRAINT)
    change_column_null(:operator_telephones, :public_id, false)
    remove_check_constraint(:operator_telephones, name: NONBLANK_CONSTRAINT)
    remove_check_constraint(:operator_telephones, name: NOT_NULL_CONSTRAINT)
  end

  def down
    add_check_constraint(
      :operator_telephones,
      "public_id IS NULL OR public_id !~ '^[[:space:]]*$'",
      name: NONBLANK_CONSTRAINT,
      validate: false,
    )
    add_check_constraint(
      :operator_telephones,
      "public_id IS NOT NULL",
      name: NOT_NULL_CONSTRAINT,
      validate: false,
    )
    change_column_null(:operator_telephones, :public_id, true)
  end
end
