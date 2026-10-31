# typed: false
# frozen_string_literal: true

# Applies one committed Zenith identity stop event to its realm OP (R5-WU06, one.md section 6.3).
#
# Idempotent and safe to retry: the OP inbound receipt for the event ID is the dedup key, written
# in the same OP transaction as the first revocation pass. Only authority issued under an epoch
# older than the event's cutoff is revoked, so a delayed or replayed stop event can never revoke a
# root established after recovery (which carries the newer epoch). Revocation goes through the one
# authority-stop primitive, which also records the Back-Channel Logout participants.
class OpIdentityEventInvalidator
  REALMS = {
    AppIdentityAuthenticationEvent => { actor: Client, receipt: OpAppInboundEventReceipt, client_id: "base-app-ww" },
    OrgIdentityAuthenticationEvent => { actor: Operator, receipt: OpOrgInboundEventReceipt, client_id: "base-org-ww" },
  }.freeze
  EVENT_TYPE = "identity_authentication_stop"
  RESOURCE_TYPES = { Client => "client", Operator => "operator" }.freeze
  # The OP root table and its actor column per realm.
  ROOTS = { Client => [ClientToken, :user_id],
            Operator => [OperatorToken, :staff_id], }.freeze

  class << self
    public

    # Called after the Zenith commit: apply now, and leave a durable retry if the OP is unavailable.
    def deliver(event:)
      call(event:)
    rescue ActiveRecord::ActiveRecordError
      enqueued = OpIdentityEventDeliveryJob.perform_later(event.class.name, event.id)
      raise ActiveJob::EnqueueError, "identity stop retry was not enqueued" unless enqueued

      :enqueued
    end

    # Returns :applied, or :duplicate when this event was already applied.
    def call(event:)
      realm = REALMS.fetch(event.class)
      unless event.realm == event.class::REALM && event.scope == IdentityAuthenticationStopRecorder::ALL_SESSIONS_SCOPE
        raise ArgumentError, "unsupported identity stop realm or scope"
      end

      actor = realm.fetch(:actor).find(Integer(event.actor_ref, 10))
      receipt_class = realm.fetch(:receipt)
      sender = receipt_sender(event.class)

      receipt_class.transaction do
        lock_receipt_key!(receipt_class, event.event_id, sender)
        prior = receipt_class.lock.find_by(event_id: event.event_id, **sender)
        if prior
          stops = OpAuthorityStopCommitter.stop_class(event.class::REALM)
            .where(authority_evidence_ref: event.event_id).includes(:epoch_cutoff).to_a
          unless receipt_matches_event?(event:, receipt: prior, actor_public_id: actor.public_id, stops:)
            raise ArgumentError, "identity stop receipt conflicts with source event"
          end

          return :duplicate
        end

        receipt_class.create!(
          event_id: event.event_id, **sender, event_type: EVENT_TYPE, committed_at: event.committed_at,
        )
        roots = stale_roots(actor, event.cutoff_epoch).order(:id).to_a
        # One all_roots_of_principal stop with its epoch cutoff (two.md 5.8 v2), then the Device
        # Sessions those roots lived in.
        OpAuthorityStopCommitter.stop_principal(
          realm: event.realm, roots:, cause: cause_for(event), principal_public_id: actor.public_id,
          authority_evidence_ref: event.event_id, cutoff_epoch: event.cutoff_epoch,
        )
        roots.each { |root| root.device_session_record&.revoke!(reason: "identity_stop_#{event.reason}") }
      end
      :applied
    end

    def receipt_sender(event_class)
      config = REALMS.fetch(event_class)
      resource_type = RESOURCE_TYPES.fetch(config.fetch(:actor))
      {
        issuer: OidcIssuer.for_resource_type(resource_type),
        realm: event_class::REALM,
        client_id: config.fetch(:client_id),
      }
    end

    def receipt_matches_event?(event:, receipt:, actor_public_id:, stops:)
      return false unless receipt.event_type == EVENT_TYPE && receipt.committed_at == event.committed_at
      return false unless event.realm == event.class::REALM &&
        event.scope == IdentityAuthenticationStopRecorder::ALL_SESSIONS_SCOPE && actor_public_id
      return false unless stops.one?

      stop = stops.first
      stop.realm == event.realm && stop.principal_public_id == actor_public_id &&
        stop.scope_id == OpAuthorityStopReference.scope_id("all_roots_of_principal") &&
        stop.cause_id == OpAuthorityStopReference.cause_id(cause_for(event)) &&
        stop.epoch_cutoff&.cutoff_epoch == event.cutoff_epoch
    end

    private

    def lock_receipt_key!(receipt_class, event_id, sender)
      parts = ["identity_stop_receipt", sender.fetch(:issuer), sender.fetch(:realm), sender.fetch(:client_id), event_id]
      key = Digest::SHA256.digest(parts.join("\0")).unpack1("q>")
      receipt_class.lease_connection.execute("SELECT pg_advisory_xact_lock(#{key.to_i})")
    end

    # D-172 S-1 / D-173: map every persisted event reason explicitly so a new event kind cannot be
    # silently recorded under the wrong authority-stop cause.
    def cause_for(event)
      IdentityAuthenticationStopRecorder.cause_for_reason!(event.reason)
    end

    # Roots issued before the cutoff epoch.
    def stale_roots(actor, cutoff_epoch)
      token_class, actor_key = ROOTS.fetch(actor.class)
      token_class.where(actor_key => actor.id)
        .where(authentication_epoch: ...cutoff_epoch)
    end
  end
end
