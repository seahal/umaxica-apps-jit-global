# frozen_string_literal: true

class RemoveLegacyOperatorAuthAdmissionBindingStatusForeignKey < ActiveRecord::Migration[8.2]
  TABLE = :operator_auth_admission_bindings
  REFERENCE_TABLE = :operator_auth_admission_binding_statuses
  FOREIGN_KEY_NAME = "fk_operator_admission_bindings_status"

  def up
    legacy_status_foreign_keys.each do |foreign_key|
      remove_foreign_key(TABLE, name: foreign_key.name)
    end
  end

  def down
    return unless legacy_status_foreign_keys.empty?

    add_foreign_key(TABLE, REFERENCE_TABLE, column: :status_id, on_delete: :restrict)
  end

  private

  def legacy_status_foreign_keys
    connection.foreign_keys(TABLE).select do |foreign_key|
      foreign_key.to_table == REFERENCE_TABLE.to_s &&
        foreign_key.column.to_s == "status_id" &&
        foreign_key.name != FOREIGN_KEY_NAME
    end.tap do |foreign_keys|
      if foreign_keys.length > 1
        raise ActiveRecord::MigrationError, "Expected at most one legacy status foreign key"
      end
    end
  end
end
