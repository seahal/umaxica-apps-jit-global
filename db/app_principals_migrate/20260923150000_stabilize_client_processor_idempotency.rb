# frozen_string_literal: true

class StabilizeClientProcessorIdempotency < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  # rubocop:disable Metrics/MethodLength
  def up
    add_column(
      :client_processor_erasure_notifications,
      :delivery_idempotency_key_digest,
      :string,
      limit: 64,
    )
    safety_assured do
      execute(<<~SQL.squish)
        UPDATE client_processor_erasure_notifications
        SET delivery_idempotency_key_digest = encode(gen_random_bytes(32), 'hex')
        WHERE delivery_idempotency_key_digest IS NULL
      SQL
    end
    add_check_constraint(
      :client_processor_erasure_notifications,
      "delivery_idempotency_key_digest IS NOT NULL",
      name: "chk_client_proc_notif_idem_digest_nn",
      validate: false,
    )
    add_check_constraint(
      :client_processor_erasure_notifications,
      "delivery_idempotency_key_digest ~ '^[0-9a-f]{64}$'",
      name: "chk_client_proc_erase_notifications_idempotency_digest",
      validate: false,
    )
    add_check_constraint(
      :client_processor_erasure_notification_attempts,
      "idempotency_key_digest ~ '^[0-9a-f]{64}$'",
      name: "chk_client_proc_erase_attempt_idempotency_digest",
      validate: false,
    )

    rename_index(
      :client_processor_erasure_notification_attempts,
      "idx_client_proc_erase_attempts_idempotency",
      "idx_client_proc_erase_attempts_idempotency_legacy_unique",
    )
    add_index(
      :client_processor_erasure_notification_attempts,
      %i(client_processor_erasure_notification_id delivery_generation idempotency_key_digest),
      name: "idx_client_proc_erase_attempts_idempotency",
      algorithm: :concurrently,
    )
    remove_index(
      :client_processor_erasure_notification_attempts,
      name: "idx_client_proc_erase_attempts_idempotency_legacy_unique",
      algorithm: :concurrently,
    )
  end
  # rubocop:enable Metrics/MethodLength

  def down
    ensure_unique_idempotency_can_be_restored!

    rename_index(
      :client_processor_erasure_notification_attempts,
      "idx_client_proc_erase_attempts_idempotency",
      "idx_client_proc_erase_attempts_idempotency_legacy_nonunique",
    )
    add_index(
      :client_processor_erasure_notification_attempts,
      %i(client_processor_erasure_notification_id delivery_generation idempotency_key_digest),
      unique: true,
      name: "idx_client_proc_erase_attempts_idempotency",
      algorithm: :concurrently,
    )
    remove_index(
      :client_processor_erasure_notification_attempts,
      name: "idx_client_proc_erase_attempts_idempotency_legacy_nonunique",
      algorithm: :concurrently,
    )
    remove_check_constraint(
      :client_processor_erasure_notification_attempts,
      name: "chk_client_proc_erase_attempt_idempotency_digest",
    )
    remove_check_constraint(
      :client_processor_erasure_notifications,
      name: "chk_client_proc_erase_notifications_idempotency_digest",
    )
    remove_column(:client_processor_erasure_notifications, :delivery_idempotency_key_digest)
  end

  private

  def ensure_unique_idempotency_can_be_restored!
    duplicate =
      safety_assured do
        connection.select_value(<<~SQL.squish)
          SELECT 1
          FROM client_processor_erasure_notification_attempts
          GROUP BY client_processor_erasure_notification_id, delivery_generation, idempotency_key_digest
          HAVING COUNT(*) > 1
          LIMIT 1
        SQL
      end
    return if duplicate.nil?

    raise ActiveRecord::IrreversibleMigration,
          "cannot restore unique processor idempotency index after retries reused a key"
  end
end
