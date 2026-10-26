# typed: false
# frozen_string_literal: true

class OperatorSecretCredentialsDestroy
  ACTION = "staff_secret_credential.delete"
  EVENT_ID = OperatorChronicleEvent::STAFF_SECRET_REMOVED

  def self.call(actor:, secret_credential:, step_up_token:, step_up_requirement:, request: nil)
    new(
      actor: actor, secret_credential: secret_credential,
      step_up_token: step_up_token, step_up_requirement: step_up_requirement, request: request,
    ).call
  end

  def initialize(actor:, secret_credential:, step_up_token:, step_up_requirement:, request:)
    @actor = actor
    @secret_credential = secret_credential
    @step_up_token = step_up_token
    @step_up_requirement = step_up_requirement
    @request = request
  end

  def call
    validate_binding!
    @actor.with_lock do
      @step_up_token.with_lock do
        verify_step_up!
        OperatorChronicle.transaction do
          OperatorSecretCredential.transaction do
            @secret_credential = OperatorSecretCredential.lock.find_by!(id: @secret_credential.id, staff_id: @actor.id)
            unless AuthMethodGuard.can_remove_secret_credential?(@actor, @secret_credential)
              raise ActiveRecord::RecordInvalid, @secret_credential
            end

            CredentialSecurityTransition.call(
              actor: @actor, current_session: @step_up_token, reason: :secret_credential_changed,
              affected_surface: "org", request: @request,
            )
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
  end

  private

  def validate_binding!
    unless @actor.is_a?(Operator) && @actor.persisted? && @secret_credential.is_a?(OperatorSecretCredential) &&
        @secret_credential.persisted? && @secret_credential.staff_id == @actor.id &&
        @step_up_token.is_a?(OperatorToken) && @step_up_token.persisted? && @step_up_token.staff_id == @actor.id
      raise ArgumentError, "operator Secret removal requires a bound actor, session and credential"
    end
  end

  def verify_step_up!
    now = OperatorToken.database_now
    requirement = @step_up_requirement
    unless requirement.is_a?(StepUpRequirement) && requirement.step_up_required? &&
        requirement.scope == "settings_secret_credential" && requirement.actor_ref == @actor.public_id &&
        requirement.token_binding == @step_up_token.public_id && @step_up_token.active_status?(now) &&
        StepUpResolver.call(token: @step_up_token, requirement:, now:).satisfied?
      raise TokenStatusManagement::StepUpEvidenceUnavailable, "operator Secret removal requires current Step-Up"
    end

    now
  end

  def ensure_audit_dependencies!
    ChronicleRecord.connected_to(role: :writing) do
      OperatorChronicleEvent.find_or_create_by!(id: EVENT_ID)
      OperatorChronicleLevel.find_or_create_by!(id: OperatorChronicleLevel::NOTHING)
    end
  end
end
