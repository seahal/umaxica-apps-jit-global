# typed: false
# frozen_string_literal: true

# Records an identity stop on the canonical actor's Zenith writer (R5-WU06, one.md sections 6.3/7.5).
#
# The actor row lock and Zenith transaction cover both the monotonic epoch and the durable
# identity_authentication_events row. After the commit, the OP applies the event with
# OpIdentityEventInvalidator; the two stores are never written in one atomic transaction.
class IdentityAuthenticationStopRecorder
  ALL_SESSIONS_SCOPE = "all_sessions"
  REASON_CAUSES = {
    "access_lock" => "administrative",
    "administrative_access_lock" => "administrative",
    "sign_risk" => "risk",
    "withdrawal_suspend" => "identity_stop",
    "withdrawal_terminate" => "identity_stop",
    "operator_withdraw" => "identity_stop",
    "operator_suspend" => "identity_stop",
    "operator_terminate" => "identity_stop",
  }.freeze

  EVENT_CLASSES = {
    "Client" => AppIdentityAuthenticationEvent,
    "Operator" => OrgIdentityAuthenticationEvent,
  }.freeze

  class << self
    public

    # reason - why authority stops (e.g. "withdrawal_suspend", "access_lock", "operator_terminate").
    # scope  - which authority is cut ("all_sessions" for every root and grant of the actor).
    def call(actor:, reason:, scope: ALL_SESSIONS_SCOPE)
      raise ArgumentError, "unsupported identity stop scope" unless scope == ALL_SESSIONS_SCOPE

      cause_for_reason!(reason)
      event_class = EVENT_CLASSES.fetch(actor.class.name)
      actor.with_lock do
        cutoff_epoch = actor.authentication_epoch + 1
        updated = actor.update_columns(authentication_epoch: cutoff_epoch) # rubocop:disable Rails/SkipsModelValidations
        raise ActiveRecord::RecordNotSaved, "identity stop epoch update failed" unless updated

        event_class.create!(
          event_id: SecureRandom.uuid, actor_ref: actor.id.to_s, realm: event_class::REALM, cutoff_epoch:, reason:,
          scope:,
          committed_at: Time.current,
        )
      end
    end

    def cause_for_reason!(reason)
      REASON_CAUSES.fetch(reason) { raise ArgumentError, "unsupported identity stop reason" }
    end
  end
end
