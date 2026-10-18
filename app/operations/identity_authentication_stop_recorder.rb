# typed: false
# frozen_string_literal: true

# Records an identity stop on the canonical actor's Zenith writer (R5-WU06, one.md sections 6.3/7.5).
#
# Must run inside the caller's actor transaction, with the actor row locked. In that one Zenith
# commit it advances the actor's monotonic authentication epoch and appends the durable
# identity_authentication_events row (the Zenith outbox). After the commit, the OP applies the event
# with OpIdentityEventInvalidator; the two stores are never written in one atomic transaction.
class IdentityAuthenticationStopRecorder
  EVENT_CLASSES = {
    "Client" => AppIdentityAuthenticationEvent,
    "Visitor" => ComIdentityAuthenticationEvent,
    "Operator" => OrgIdentityAuthenticationEvent,
  }.freeze

  class << self
    public

    # reason - why authority stops (e.g. "withdrawal_suspend", "access_lock", "operator_terminate").
    # scope  - which authority is cut ("all_sessions" for every root and grant of the actor).
    def call(actor:, reason:, scope: "all_sessions")
      event_class = EVENT_CLASSES.fetch(actor.class.name)
      cutoff_epoch = actor.authentication_epoch + 1
      actor.update_columns(authentication_epoch: cutoff_epoch) # rubocop:disable Rails/SkipsModelValidations
      event_class.create!(
        event_id: SecureRandom.uuid, actor_ref: actor.id.to_s, realm: event_class::REALM, cutoff_epoch:, reason:,
        scope:,
        committed_at: Time.current,
      )
    end
  end
end
