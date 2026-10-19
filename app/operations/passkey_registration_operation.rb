# typed: false
# frozen_string_literal: true

# The single Passkey registration writer. It locks the owning identity, so the model's
# ten-Passkey limit validation runs serialized for that owner, then saves the Passkey and its audit
# outbox row in one principal transaction. The limit is enforced only for writers that use this
# operation; direct inserts are a recorded gap
# (plans/backlog/2026-10-19-passkey-limit-enforcement-gap.md).
class PasskeyRegistrationOperation
  CONFIG = {
    ClientPasskey => { owner_class: Client, owner_key: :user_id },
    VisitorPasskey => { owner_class: Visitor, owner_key: :visitor_id },
    OperatorPasskey => { owner_class: Operator, owner_key: :staff_id },
  }.freeze

  class << self
    public

    def credential_id_conflict?(error)
      cause = error.cause
      return false unless cause.is_a?(PG::UniqueViolation)

      constraint = cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      %w(
        index_client_passkeys_on_webauthn_id
        index_visitor_passkeys_on_webauthn_id
        index_operator_passkeys_on_webauthn_id
      ).include?(constraint)
    end

    def call!(actor:, passkey: nil, passkey_class: nil, attributes: nil, audit: nil)
      passkey_class ||= passkey.class
      config =
        CONFIG.fetch(passkey_class) do
          raise ArgumentError, "unsupported passkey class: #{passkey_class}"
        end
      owner_class = config.fetch(:owner_class)
      unless actor.is_a?(owner_class)
        raise ArgumentError, "#{passkey_class} requires an actor from #{owner_class}"
      end

      owner_key = config.fetch(:owner_key)
      record = passkey || passkey_class.new(attributes || {})
      unless record.is_a?(passkey_class) && record.new_record?
        raise ArgumentError, "Passkey registration requires a new #{passkey_class}"
      end

      actor.class.connection_class_for_self.connected_to(role: :writing) do
        actor.class.transaction(requires_new: true) do
          actor.lock!
          record[owner_key] = actor.id
          record.save!
          record_audit!(record, actor, audit) if audit
          record
        end
      end
    end

    private

    def record_audit!(record, actor, audit)
      PasskeyAuditOutbox.record_for!(
        passkey: record,
        event_type: audit.fetch(:event_type),
        surface: audit.fetch(:surface),
        actor_ref: audit[:actor_ref].presence || actor.public_id,
        operation_ref: audit[:operation_ref],
        metadata: audit.fetch(:metadata, {}),
        occurred_at: audit[:occurred_at],
      )
    end
  end
end
