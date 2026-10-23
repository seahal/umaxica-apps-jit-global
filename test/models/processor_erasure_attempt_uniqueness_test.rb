# frozen_string_literal: true

require "test_helper"

class ProcessorErasureAttemptUniquenessTest < ActiveSupport::TestCase
  SURFACES = [
    [Client, ClientStatus::ACTIVE, ClientVisibility::USER, ClientPrivacyRequest, :client,
     ClientProcessorErasureNotification, :client_privacy_request, ClientProcessorErasureNotificationAttempt,],
    [Visitor, VisitorStatus::ACTIVE, VisitorVisibility::VISITOR, VisitorPrivacyRequest, :visitor,
     VisitorProcessorErasureNotification, :visitor_privacy_request, VisitorProcessorErasureNotificationAttempt,],
  ].freeze

  SURFACES.each do |principal_class, status, visibility, request_class, owner_key,
                    notification_class, request_key, attempt_class|
    test "#{attempt_class.name} keeps attempt claims serialized and raw uniqueness authoritative" do
      principal = principal_class.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, status_id: status,
        visibility_id: visibility,
      )
      request = request_class.create!(owner_key => principal)
      notification = notification_class.create!(request_key => request, :processor_key => "email_delivery")
      now = notification_class.database_now
      policy = ProcessorErasureRetryPolicy.new(max_attempts: 3, retry_delay_seconds: 0)
      first = notification.begin_attempt!(retry_policy: policy, now: now)

      assert_equal 1, first.attempt_number
      assert_nil notification.begin_attempt!(retry_policy: policy, now: now)
      attributes = first.attributes.except("id", "created_at", "updated_at")
      assert_raises(ActiveRecord::RecordNotUnique) do
        attempt_class.transaction(requires_new: true) { attempt_class.new(attributes).save!(validate: false) }
      end
      notification.mark_retryable_failure!(
        attempt: first, policy: policy, code: "temporary",
        message: "Retry", now: now,
      )
      second = notification.begin_attempt!(retry_policy: policy, now: now)

      assert_equal 2, second.attempt_number
      assert_equal first.delivery_generation, second.delivery_generation
      assert_equal 2, notification.attempts.count
      # The same ordinal in a different delivery generation is a distinct DB key.
      next_generation = attempt_class.create!(attributes.merge(delivery_generation: first.delivery_generation + 1))

      assert_equal 1, next_generation.attempt_number
    end

    test "#{attempt_class.name} refuses the same notification generation and ordinal before creation" do
      principal = principal_class.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, status_id: status,
        visibility_id: visibility,
      )
      request = request_class.create!(owner_key => principal)
      notification = notification_class.create!(request_key => request, :processor_key => "email_delivery")
      first = notification.begin_attempt!(
        retry_policy: ProcessorErasureRetryPolicy.new(
          max_attempts: 3,
          retry_delay_seconds: 0,
        ),
      )
      duplicate = attempt_class.new(first.attributes.except("id", "created_at", "updated_at"))

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:attempt_number, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    end
  end
end
