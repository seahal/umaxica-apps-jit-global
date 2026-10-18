# typed: false
# frozen_string_literal: true

class OperatorSecretCredentialsDestroy
  ACTION = "staff_secret_credential.delete"
  EVENT_ID = OperatorChronicleEvent::STAFF_SECRET_REMOVED

  def self.call(actor:, secret_credential:)
    new(actor: actor, secret_credential: secret_credential).call
  end

  def initialize(actor:, secret_credential:)
    @actor = actor
    @secret_credential = secret_credential
  end

  def call
    OperatorChronicle.transaction do
      OperatorSecretCredential.transaction do
        @actor.with_lock do
          @secret_credential = OperatorSecretCredential.lock.find_by!(id: @secret_credential.id, staff_id: @actor.id)
          unless AuthMethodGuard.can_remove_secret_credential?(@actor, @secret_credential)
            raise ActiveRecord::RecordInvalid, @secret_credential
          end

          ensure_audit_dependencies!
          @secret_credential.discard_now!(purge_after: 1.day)
          @secret_credential.staff_secret_status_id = OperatorSecretCredential.status_id_for(:deleted)
          OperatorChronicle.create!(
            actor: @actor,
            subject_type: "OperatorSecretCredential",
            subject_id: @secret_credential.id.to_s,
            event_id: EVENT_ID,
            occurred_at: Time.current,
            context: { action: ACTION },
          )
          @secret_credential.save!
        end
      end
    end
  end

  private

  def ensure_audit_dependencies!
    ChronicleRecord.connected_to(role: :writing) do
      OperatorChronicleEvent.find_or_create_by!(id: EVENT_ID)
      OperatorChronicleLevel.find_or_create_by!(id: OperatorChronicleLevel::NOTHING)
    end
  end
end
