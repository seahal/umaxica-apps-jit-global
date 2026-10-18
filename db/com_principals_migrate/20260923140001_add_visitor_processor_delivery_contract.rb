# frozen_string_literal: true

class AddVisitorProcessorDeliveryContract < ActiveRecord::Migration[8.2]
  # One migration unit keeps the notification columns, status seed, and attempt table atomic.
  # rubocop:disable Metrics/MethodLength
  def up
    add_column(
      :visitor_processor_erasure_notifications, :delivery_generation, :bigint,
      null: false, default: 1,
    )
    add_column(:visitor_processor_erasure_notifications, :permanent_failed_at, :datetime)
    add_check_constraint(
      :visitor_processor_erasure_notifications,
      "delivery_generation > 0",
      name: "chk_visitor_proc_erase_notifications_generation_positive",
      validate: false,
    )
    add_check_constraint(
      :visitor_processor_erasure_notifications,
      "retry_count >= 0",
      name: "chk_visitor_proc_erase_notifications_retry_count_nonnegative",
      validate: false,
    )

    safety_assured do
      execute(<<~SQL.squish)
        UPDATE visitor_processor_erasure_notification_statuses
        SET name = 'RETRYABLE_FAILURE'
        WHERE id = 30
      SQL
      execute(<<~SQL.squish)
        INSERT INTO visitor_processor_erasure_notification_statuses (id, name)
        VALUES (50, 'PERMANENT_FAILURE')
        ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name
      SQL
    end

    create_table(:visitor_processor_erasure_notification_attempts) do |t|
      t.references(
        :visitor_processor_erasure_notification,
        null: false,
        foreign_key: {
          # Attempt rows have no independent retention window. They inherit
          # the notification's purge eligibility and must be removed with it
          # by the set-based retention purge.
          on_delete: :cascade,
          name: "fk_visitor_proc_erase_attempt_notification",
        },
      )
      t.bigint(:delivery_generation, null: false)
      t.integer(:attempt_number, null: false)
      t.string(:processor_key, null: false)
      t.string(:idempotency_key_digest, limit: 64, null: false)
      t.string(:outcome, null: false)
      t.datetime(:started_at, null: false)
      t.datetime(:finished_at)
      t.datetime(:lease_expires_at)
      t.string(:receipt_reference_digest, limit: 64)
      t.string(:error_code, default: "", null: false)
      t.string(:error_message, default: "", null: false)
      t.timestamps

      t.index(
        %i(visitor_processor_erasure_notification_id delivery_generation attempt_number),
        unique: true,
        name: "idx_visitor_proc_erase_attempts_generation_number",
      )
      t.index(
        %i(visitor_processor_erasure_notification_id delivery_generation idempotency_key_digest),
        unique: true,
        name: "idx_visitor_proc_erase_attempts_idempotency",
      )
      t.index(
        %i(visitor_processor_erasure_notification_id delivery_generation outcome),
        name: "idx_visitor_proc_erase_attempts_processing",
      )
      t.check_constraint(
        "delivery_generation > 0",
        name: "chk_visitor_proc_erase_attempt_generation_positive",
        validate: false,
      )
      t.check_constraint(
        "attempt_number > 0",
        name: "chk_visitor_proc_erase_attempt_number_positive",
        validate: false,
      )
      t.check_constraint(
        "outcome IN ('IN_FLIGHT', 'ACCEPTED_PENDING', 'SUCCEEDED', 'RETRYABLE_FAILURE', 'PERMANENT_FAILURE')",
        name: "chk_visitor_proc_erase_attempt_outcome",
        validate: false,
      )
    end
  end
  # rubocop:enable Metrics/MethodLength

  def down
    drop_table(:visitor_processor_erasure_notification_attempts)
    remove_check_constraint(
      :visitor_processor_erasure_notifications,
      name: "chk_visitor_proc_erase_notifications_retry_count_nonnegative",
    )
    remove_check_constraint(
      :visitor_processor_erasure_notifications,
      name: "chk_visitor_proc_erase_notifications_generation_positive",
    )
    remove_column(:visitor_processor_erasure_notifications, :permanent_failed_at)
    remove_column(:visitor_processor_erasure_notifications, :delivery_generation)
    safety_assured do
      execute(<<~SQL.squish)
        UPDATE visitor_processor_erasure_notifications
        SET status_id = 30
        WHERE status_id = 50
      SQL
      execute("DELETE FROM visitor_processor_erasure_notification_statuses WHERE id = 50")
      execute("UPDATE visitor_processor_erasure_notification_statuses SET name = 'FAILED' WHERE id = 30")
    end
  end
end
