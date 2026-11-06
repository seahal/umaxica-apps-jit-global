# frozen_string_literal: true

class NormalizeOperatorAuthAdmissionBindingStatusForeignKey < ActiveRecord::Migration[8.2]
  TABLE = :operator_auth_admission_bindings
  REFERENCE_TABLE = :operator_auth_admission_binding_statuses
  FOREIGN_KEY_NAME = "fk_operator_admission_bindings_status"

  def up
    existing_foreign_key = named_status_foreign_key
    if existing_foreign_key
      assert_expected_foreign_key!(existing_foreign_key)
      return
    end

    add_foreign_key(
      TABLE,
      REFERENCE_TABLE,
      column: :status_id,
      name: FOREIGN_KEY_NAME,
      on_delete: :restrict,
      validate: false,
    )
  end

  def down
    existing_foreign_key = named_status_foreign_key
    return unless existing_foreign_key

    assert_expected_foreign_key!(existing_foreign_key)
    remove_foreign_key(TABLE, name: FOREIGN_KEY_NAME)
  end

  private

  def named_status_foreign_key
    connection.foreign_keys(TABLE).find { |foreign_key| foreign_key.name == FOREIGN_KEY_NAME }
  end

  def assert_expected_foreign_key!(foreign_key)
    return if foreign_key.to_table == REFERENCE_TABLE.to_s &&
      foreign_key.column.to_s == "status_id" &&
      foreign_key.on_delete == :restrict

    raise ActiveRecord::MigrationError, "#{FOREIGN_KEY_NAME} exists with an unexpected definition"
  end
end
