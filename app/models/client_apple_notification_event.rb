# typed: false
# frozen_string_literal: true

class ClientAppleNotificationEvent < AppPrincipalRecord
  EVENT_TYPES = %w(email-enabled email-disabled consent-revoked account-deleted).freeze
  STATUSES = %w(received retrying completed dead_letter).freeze
  MAXIMUM_ATTEMPTS = 10
  MAXIMUM_RETRY_WINDOW = 24.hours

  belongs_to :client, optional: true, inverse_of: :client_apple_notification_events
  belongs_to :client_external_identity, optional: true, inverse_of: :client_apple_notification_events

  validates :jti, presence: true, uniqueness: true
  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :processing_attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :received_at, :occurred_at, presence: true
  validates :event_type, :status, length: { maximum: 32 }

  scope :due, ->(now = Time.current) { where(status: %w(received retrying)).where(next_retry_at: ..now) }

  def terminal?
    %w(completed dead_letter).include?(status)
  end

  def complete!(now: Time.current)
    update!(status: "completed", processed_at: now, next_retry_at: nil, failure_code: "")
  end

  def retry_or_dead_letter!(code:, now: Time.current)
    next_attempt = processing_attempts + 1
    if next_attempt >= MAXIMUM_ATTEMPTS || now >= received_at + MAXIMUM_RETRY_WINDOW
      update!(
        status: "dead_letter",
        processing_attempts: next_attempt,
        dead_lettered_at: now,
        next_retry_at: nil,
        failure_code: code,
      )
      return :dead_letter
    end

    update!(
      status: "retrying",
      processing_attempts: next_attempt,
      next_retry_at: now + [(2**next_attempt).minutes, 2.hours].min,
      failure_code: code,
    )
    :retrying
  end
end
