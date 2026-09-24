# frozen_string_literal: true

class ValidateClientProcessorDeliveryContract < ActiveRecord::Migration[8.2]
  NOT_NULL_CONSTRAINT = "chk_client_proc_notif_idem_digest_nn"

  CONSTRAINTS = {
    client_processor_erasure_notifications: %w(
      chk_client_proc_erase_notifications_generation_positive
      chk_client_proc_erase_notifications_retry_count_nonnegative
      chk_client_proc_erase_notifications_idempotency_digest
      chk_client_proc_notif_idem_digest_nn
    ),
    client_processor_erasure_notification_attempts: %w(
      chk_client_proc_erase_attempt_generation_positive
      chk_client_proc_erase_attempt_number_positive
      chk_client_proc_erase_attempt_outcome
      chk_client_proc_erase_attempt_idempotency_digest
    ),
  }.freeze

  def up
    CONSTRAINTS.each do |table_name, constraint_names|
      constraint_names.each do |constraint_name|
        validate_check_constraint(table_name, name: constraint_name)
      end
    end

    safety_assured do
      change_column_null(:client_processor_erasure_notifications, :delivery_idempotency_key_digest, false)
    end
    remove_check_constraint(
      :client_processor_erasure_notifications,
      name: NOT_NULL_CONSTRAINT,
    )
  end

  def down
    add_check_constraint(
      :client_processor_erasure_notifications,
      "delivery_idempotency_key_digest IS NOT NULL",
      name: "chk_client_proc_notif_idem_digest_nn",
      validate: false,
    )
    safety_assured do
      change_column_null(:client_processor_erasure_notifications, :delivery_idempotency_key_digest, true)
    end
    remove_check_constraint(
      :client_processor_erasure_notifications,
      name: NOT_NULL_CONSTRAINT,
    )
  end
end
