# typed: false
# frozen_string_literal: true

class OperatorSecretCredentialsUpdate
  ACTION = "staff_secret_credential.update"
  EVENT_ID = OperatorChronicleEvent::STAFF_SECRET_UPDATED

  Result = Struct.new(:secret_credential, keyword_init: true)

  def self.call(actor:, secret_credential:, params:, step_up_token:, step_up_evidence: nil, request: nil)
    new(
      actor: actor, secret_credential: secret_credential, params: params,
      step_up_token: step_up_token, step_up_evidence: step_up_evidence, request: request,
    ).call
  end

  def initialize(actor:, secret_credential:, params:, step_up_token:, step_up_evidence:, request:)
    @actor = actor
    @secret_credential = secret_credential
    @params = params
    @step_up_token = step_up_token
    @step_up_evidence = step_up_evidence
    @request = request
  end

  def call
    validate_binding!
    @actor.with_lock do
      unless @actor.login_allowed?
        raise TokenStatusManagement::StepUpEvidenceUnavailable, "operator Secret update requires an active operator"
      end

      device = OperatorDeviceSession.find_by(id: @step_up_token.device_session_id, staff_id: @actor.id)
      unless device
        raise TokenStatusManagement::StepUpEvidenceUnavailable, "operator Secret update requires a current device"
      end

      device.with_lock do
        unless device.usable? && device.current_refresh_token_id == @step_up_token.id
          raise TokenStatusManagement::StepUpEvidenceUnavailable, "operator Secret update requires a current device"
        end

        mutate_with_current_device!(device)
      end
    end

    Result.new(secret_credential: @secret_credential)
  end

  private

  def mutate_with_current_device!(device)
    @step_up_token.with_lock do
      unless @step_up_token.device_session_id == device.id
        raise TokenStatusManagement::StepUpEvidenceUnavailable, "operator Secret update requires a current session"
      end

      verify_step_up!
      OperatorChronicle.transaction do
        OperatorSecretCredential.transaction do
          @secret_credential = OperatorSecretCredential.lock.find_by!(
            id: @secret_credential.id, staff_id: @actor.id,
          )
          if disabling? && !AuthMethodGuard.can_remove_secret_credential?(@actor, @secret_credential)
            raise ActiveRecord::RecordInvalid, @secret_credential
          end

          was_active = @secret_credential.active?
          @secret_credential.name = @params[:name].to_s.strip if @params[:name].present?
          @secret_credential.staff_secret_status_id = status_id_for(@params[:enabled]) if @params.key?(:enabled)
          credential_removed = was_active &&
            @secret_credential.staff_secret_status_id == OperatorSecretCredentialStatus::REVOKED

          if credential_removed
            CredentialSecurityTransition.call(
              actor: @actor, current_session: @step_up_token, reason: :secret_credential_changed,
              affected_surface: "org", request: @request,
            )
          end

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
  end

  def validate_binding!
    unless @actor.is_a?(Operator) && @actor.persisted? && @secret_credential.is_a?(OperatorSecretCredential) &&
        @secret_credential.persisted? && @step_up_token.is_a?(OperatorToken) && @step_up_token.persisted? &&
        @step_up_token.staff_id == @actor.id && @secret_credential.staff_id == @actor.id
      raise ArgumentError, "operator Secret update requires a bound actor, session and credential"
    end
  end

  def verify_step_up!
    return if StepUpEvidenceVerifier.call(
      evidence: @step_up_evidence, actor: @actor, token: @step_up_token,
    )

    raise TokenStatusManagement::StepUpEvidenceUnavailable, "operator Secret update requires current Step-Up"
  end

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
