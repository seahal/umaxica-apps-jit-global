# typed: false
# frozen_string_literal: true

# Applies one committed Zenith identity stop event to its realm OP (R5-WU06, one.md section 6.3).
#
# Idempotent and safe to retry: the OP inbound receipt for the event ID is the dedup key, written
# in the same OP transaction as the first revocation pass. Only authority issued under an epoch
# older than the event's cutoff is revoked, so a delayed or replayed stop event can never revoke a
# root established after recovery (which carries the newer epoch). Revocation reuses the existing
# OP logout path, which also schedules logout delivery to the affected RPs.
class OpIdentityEventInvalidator
  REALMS = {
    AppIdentityAuthenticationEvent => { actor: Client, receipt: OpAppInboundEventReceipt, client_id: "base-app-ww" },
    ComIdentityAuthenticationEvent => { actor: Visitor, receipt: OpComInboundEventReceipt, client_id: "base-com-ww" },
    OrgIdentityAuthenticationEvent => { actor: Operator, receipt: OpOrgInboundEventReceipt, client_id: "base-org-ww" },
  }.freeze
  EVENT_TYPE = "identity_authentication_stop"
  # The OP root table and its actor column per realm.
  ROOTS = { Client => [ClientToken, :user_id],
            Visitor => [VisitorToken, :visitor_id],
            Operator => [OperatorToken, :staff_id], }.freeze

  class << self
    public

    # Called after the Zenith commit: apply now, and leave a durable retry if the OP is unavailable.
    def deliver(event:)
      call(event:)
    rescue ActiveRecord::ActiveRecordError
      OpIdentityEventDeliveryJob.perform_later(event.class.name, event.id)
      :enqueued
    end

    # Returns :applied, or :duplicate when this event was already applied.
    def call(event:)
      realm = REALMS.fetch(event.class)
      actor = realm.fetch(:actor).find(Integer(event.actor_ref, 10))
      receipt_class = realm.fetch(:receipt)

      receipt_class.transaction do
        return :duplicate if receipt_class.lock.exists?(event_id: event.event_id)

        receipt_class.create!(
          event_id: event.event_id, issuer: OidcIssuer.for_resource_type(actor_type(actor)),
          realm: event.realm, client_id: realm.fetch(:client_id), event_type: EVENT_TYPE,
          committed_at: event.committed_at,
        )
        stale_roots(actor, event.cutoff_epoch).find_each do |token|
          AuthenticationLogoutCurrentSession.call(resource: actor, token:, reason: "identity_stop_#{event.reason}")
        end
      end
      :applied
    end

    private

    # Roots issued before the cutoff epoch.
    def stale_roots(actor, cutoff_epoch)
      token_class, actor_key = ROOTS.fetch(actor.class)
      token_class.not_revoked.where(actor_key => actor.id)
        .where(authentication_epoch: ...cutoff_epoch)
    end

    def actor_type(actor)
      { Client => "client", Visitor => "visitor", Operator => "operator" }.fetch(actor.class)
    end
  end
end
