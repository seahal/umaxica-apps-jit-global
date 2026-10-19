# typed: false
# frozen_string_literal: true

# Principal-side transactional outbox for Passkey lifecycle facts. The source row is written in
# the same transaction as the credential mutation; Chronicle delivery is intentionally asynchronous.
module PasskeyAuditOutbox
  extend ActiveSupport::Concern

  EVENT_TYPES = %w(
    passkey.registered.signup
    passkey.registered.settings
    passkey.description_changed
    passkey.removed
    passkey.revoked
    passkey.registration_cancelled
    passkey.purged
  ).freeze

  module ClassMethods
    public

    def record!(passkey:, event_type:, surface:, actor_ref: nil, operation_ref: nil, metadata: {}, occurred_at: nil)
      unless lease_connection.transaction_open?
        raise ArgumentError, "Passkey audit requires the principal transaction"
      end
      raise ArgumentError, "unsupported Passkey audit event" unless EVENT_TYPES.include?(event_type.to_s)
      raise ArgumentError, "surface does not match Passkey outbox" unless surface.to_s == surface_name
      if (metadata || {}).stringify_keys.keys.intersect?(%w(surface external_id actor_ref))
        raise ArgumentError, "Passkey audit metadata cannot replace authoritative references"
      end

      create!(
        event_uuid: SecureRandom.uuid,
        event_type: event_type.to_s,
        surface: surface.to_s,
        external_id: passkey.external_id,
        actor_ref: actor_ref,
        operation_ref: operation_ref,
        metadata: ChronicleRecordPolicy.sanitize(metadata || {}),
        occurred_at: occurred_at || database_now,
      )
    end

    def surface_name
      case name
      when "ClientPasskeyAuditOutbox" then "app"
      when "VisitorPasskeyAuditOutbox" then "com"
      when "OperatorPasskeyAuditOutbox" then "org"
      else raise ArgumentError, "unsupported Passkey audit outbox #{name}"
      end
    end
  end

  class << self
    public

    def source_for(passkey)
      case passkey
      when ClientPasskey then ClientPasskeyAuditOutbox
      when VisitorPasskey then VisitorPasskeyAuditOutbox
      when OperatorPasskey then OperatorPasskeyAuditOutbox
      else raise ArgumentError, "unsupported Passkey audit subject #{passkey.class}"
      end
    end

    def record_for!(passkey:, event_type:, surface:, actor_ref: nil, operation_ref: nil, metadata: {}, occurred_at: nil)
      source_for(passkey).record!(
        passkey: passkey, event_type: event_type, surface: surface, actor_ref: actor_ref,
        operation_ref: operation_ref, metadata: metadata, occurred_at: occurred_at,
      )
    end
  end
end
