# frozen_string_literal: true

class ClientContactAuditOutbox < AppZenithRecord
  EVENT_NAMES = %w(finalized released preferences_changed).freeze

  include ContactAuditOutbox

  attr_readonly :event_uuid, :contact_kind, :event_name, :owner_ref, :contact_ref,
                :operation_ref, :actor_ref, :occurred_at

  validates :event_uuid, :owner_ref, :contact_ref, :operation_ref, :occurred_at, presence: true
  validates :contact_kind, inclusion: { in: %w(email telephone) }
  validates :event_name, inclusion: { in: EVENT_NAMES }
  validate :preferences_changed_requires_email_actor

  class << self
    public

    def record_preferences_changed!(actor:, email:)
      unless lease_connection.transaction_open?
        raise ArgumentError, "Email preference audit requires the source Zenith transaction"
      end
      unless actor.is_a?(Client) && actor.persisted? && email.is_a?(ClientEmail) && email.persisted? &&
          email.user_id == actor.id
        raise ArgumentError, "Email preference audit owner does not match its contact"
      end
      unless email.saved_change_to_promotional? || email.saved_change_to_notifiable?
        raise ArgumentError, "Email preference audit requires a committed preference change"
      end

      record!(
        contact_kind: "email", event_name: "preferences_changed", owner_ref: actor.public_id,
        contact_ref: email.public_id, operation_ref: SecureRandom.uuid, actor_ref: actor.public_id,
      )
    end
  end

  private

  def preferences_changed_requires_email_actor
    return unless event_name == "preferences_changed"

    errors.add(:contact_kind, :invalid) unless contact_kind == "email"
    errors.add(:actor_ref, :blank) if actor_ref.blank?
  end
end
