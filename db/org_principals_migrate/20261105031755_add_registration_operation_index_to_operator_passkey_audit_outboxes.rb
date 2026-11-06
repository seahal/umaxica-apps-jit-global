# frozen_string_literal: true

class AddRegistrationOperationIndexToOperatorPasskeyAuditOutboxes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    duplicates = connection.select_value(<<~SQL)
      SELECT EXISTS (
        SELECT 1
        FROM operator_passkey_audit_outboxes
        WHERE event_type IN ('passkey.registered.signup', 'passkey.registered.settings')
          AND operation_ref IS NOT NULL
          AND operation_ref <> ''
        GROUP BY operation_ref
        HAVING COUNT(*) > 1
      )
    SQL
    raise ActiveRecord::MigrationError, "duplicate passkey registration operation references exist" if duplicates

    add_index(:operator_passkey_audit_outboxes, :operation_ref, unique: true,
              where: "event_type IN ('passkey.registered.signup', 'passkey.registered.settings') " \
                     "AND operation_ref IS NOT NULL AND operation_ref <> ''",
              name: "idx_operator_passkey_registration_operation", algorithm: :concurrently)
  end
end
