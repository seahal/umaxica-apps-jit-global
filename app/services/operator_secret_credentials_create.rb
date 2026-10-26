# typed: false
# frozen_string_literal: true

class OperatorSecretCredentialsCreate
  ACTION = "staff_secret_credential.create"
  EVENT_ID = OperatorChronicleEvent::STAFF_SECRET_CREATED

  Result = Struct.new(:secret_credential, :raw_secret_credential, keyword_init: true)

  def self.call(actor:, staff:, params:, raw_secret_credential: nil, step_up_token:, step_up_requirement:,
                step_up_bootstrap:)
    new(
      actor: actor, staff: staff, params: params, raw_secret_credential: raw_secret_credential,
      step_up_token: step_up_token, step_up_requirement: step_up_requirement, step_up_bootstrap: step_up_bootstrap,
    ).call
  end

  def initialize(actor:, staff:, params:, raw_secret_credential:, step_up_token:, step_up_requirement:,
                 step_up_bootstrap:)
    @actor = actor
    @staff = staff
    @params = params
    @raw_secret_credential = raw_secret_credential
    @step_up_token = step_up_token
    @step_up_requirement = step_up_requirement
    @step_up_bootstrap = step_up_bootstrap
  end

  def call
    validate_binding!
    @actor.with_lock do
      @step_up_token.with_lock do
        now = verify_step_up!
        raw_secret_credential = @raw_secret_credential.presence ||
          OperatorSecretCredential.generate_raw_secret_credential
        secret_credential = @staff.staff_secret_credentials.new(name: @params[:name].to_s.strip)
        secret_credential.raw_secret_credential = raw_secret_credential
        secret_credential.password = raw_secret_credential
        secret_credential.staff_secret_status_id = status_id_for(@params[:enabled])

        OperatorChronicle.transaction do
          OperatorSecretCredential.transaction do
            ensure_audit_dependencies!
            secret_credential.save!
            OperatorChronicle.create!(
              actor: @actor,
              subject_type: "OperatorSecretCredential",
              subject_id: secret_credential.id.to_s,
              event_id: EVENT_ID,
              occurred_at: Time.current,
              context: { action: ACTION },
            )
            consume_step_up!(now)
          end
        end

        Result.new(secret_credential: secret_credential, raw_secret_credential: raw_secret_credential)
      end
    end
  end

  private

  def validate_binding!
    unless @actor.is_a?(Operator) && @actor.persisted? && @staff == @actor &&
        @step_up_token.is_a?(OperatorToken) && @step_up_token.persisted? && @step_up_token.staff_id == @actor.id
      raise ArgumentError, "operator Secret creation requires a bound actor and session"
    end
  end

  def verify_step_up!
    now = OperatorToken.database_now
    if @step_up_requirement.nil?
      unless @step_up_bootstrap && StepUpBootstrapEligibilityQuery.call(actor: @actor)
        raise TokenStatusManagement::StepUpEvidenceUnavailable, "operator Secret creation requires Step-Up"
      end

      return now
    end

    requirement = @step_up_requirement
    unless !@step_up_bootstrap && requirement.is_a?(StepUpRequirement) && requirement.step_up_required? &&
        requirement.scope == "settings_secret_credential" && requirement.actor_ref == @actor.public_id &&
        requirement.token_binding == @step_up_token.public_id && @step_up_token.active_status?(now) &&
        StepUpResolver.call(token: @step_up_token, requirement:, now:).satisfied?
      raise TokenStatusManagement::StepUpEvidenceUnavailable, "operator Secret creation requires current Step-Up"
    end

    now
  end

  def consume_step_up!(now)
    return if @step_up_requirement.nil?

    @step_up_token.consume_step_up_evidence!(requirement: @step_up_requirement, now:)
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
