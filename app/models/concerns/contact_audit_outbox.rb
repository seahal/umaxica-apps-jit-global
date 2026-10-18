# frozen_string_literal: true

# Requires the Source model's lease_connection, create!, and database_now.
# Including this module installs no callbacks or validation hooks.
module ContactAuditOutbox
  extend ActiveSupport::Concern

  module ClassMethods
    public

    def record!(contact_kind:, event_name:, owner_ref:, contact_ref:, operation_ref:, actor_ref:)
      unless lease_connection.transaction_open?
        raise ArgumentError, "Contact audit requires the Source Zenith transaction"
      end

      create!(
        event_uuid: SecureRandom.uuid, contact_kind: contact_kind, event_name: event_name,
        owner_ref: owner_ref, contact_ref: contact_ref, operation_ref: operation_ref,
        actor_ref: actor_ref, occurred_at: database_now,
      )
    end
  end
end
