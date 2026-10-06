# typed: false
# frozen_string_literal: true

class OperatorSecretCredentialsUpdate
  ACTION = "staff_secret_credential.update"
  EVENT_ID = OperatorChronicleEvent::STAFF_SECRET_UPDATED

  Result = Struct.new(:secret_credential, keyword_init: true)

  def self.call(actor:, secret_credential:, params:)
    new(actor: actor, secret_credential: secret_credential, params: params).call
  end

  def initialize(actor:, secret_credential:, params:)
    @actor = actor
    @secret_credential = secret_credential
    @params = params
  end

  def call
    OperatorChronicle.transaction do
      OperatorSecretCredential.transaction do
        @actor.with_lock do
          @secret_credential = OperatorSecretCredential.lock.find_by!(id: @secret_credential.id, staff_id: @actor.id)
          if disabling? && !AuthMethodGuard.can_remove_secret_credential?(@actor, @secret_credential)
            raise ActiveRecord::RecordInvalid, @secret_credential
          end

          @secret_credential.name = @params[:name].to_s.strip if @params[:name].present?
          @secret_credential.staff_secret_status_id = status_id_for(@params[:enabled]) if @params.key?(:enabled)

          ensure_audit_dependencies!
          @secret_credential.save!
          OperatorChronicle.create!(
            actor: @actor,
            subject_type: "OperatorSecretCredential",
            subject_id: @secret_credential.id.to_s,
            event_id: EVENT_ID,
            occurred_at: Time.current,
            context: { action: ACTION },
          )
        end
      end
    end

    Result.new(secret_credential: @secret_credential)
  end

  private

  def disabling?
    @params.key?(:enabled) && !ActiveModel::Type::Boolean.new.cast(@params[:enabled])
  end

  def status_id_for(enabled_param)
    enabled = ActiveModel::Type::Boolean.new.cast(enabled_param)
    status = enabled ? :active : :revoked
    OperatorSecretCredential.status_id_for(status)
  end

  def ensure_audit_dependencies!
    ChronicleRecord.connected_to(role: :writing) do
      OperatorChronicleEvent.find_or_create_by!(id: EVENT_ID)
      OperatorChronicleLevel.find_or_create_by!(id: OperatorChronicleLevel::NOTHING)
    end
  end
end
