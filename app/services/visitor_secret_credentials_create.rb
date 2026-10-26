# typed: false
# frozen_string_literal: true

class VisitorSecretCredentialsCreate
  ACTION = "visitor_secret_credential.create"

  Result = Struct.new(:secret_credential, :raw_secret_credential, keyword_init: true)

  def self.call(actor:, visitor:, params:, raw_secret_credential: nil, step_up_token:, step_up_requirement:,
                step_up_bootstrap:)
    new(
      actor: actor, visitor: visitor, params: params, raw_secret_credential: raw_secret_credential,
      step_up_token: step_up_token, step_up_requirement: step_up_requirement, step_up_bootstrap: step_up_bootstrap,
    ).call
  end

  def initialize(actor:, visitor:, params:, raw_secret_credential:, step_up_token:, step_up_requirement:,
                 step_up_bootstrap:)
    @actor = actor
    @visitor = visitor
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
          VisitorSecretCredential.generate_raw_secret_credential
        secret_credential = @visitor.visitor_secret_credentials.new(name: @params[:name].to_s.strip)
        secret_credential.raw_secret_credential = raw_secret_credential
        secret_credential.password = raw_secret_credential
        secret_credential.visitor_secret_credential_status_id = status_id_for(@params[:enabled])

        VisitorSecretCredential.transaction do
          secret_credential.save!
          consume_step_up!(now)
        end

        Result.new(secret_credential: secret_credential, raw_secret_credential: raw_secret_credential)
      end
    end
  end

  private

  def validate_binding!
    unless @actor.is_a?(Visitor) && @actor.persisted? && @visitor == @actor &&
        @step_up_token.is_a?(VisitorToken) && @step_up_token.persisted? && @step_up_token.visitor_id == @actor.id
      raise ArgumentError, "visitor Secret creation requires a bound actor and session"
    end
  end

  def verify_step_up!
    now = VisitorToken.database_now
    if @step_up_requirement.nil?
      unless @step_up_bootstrap && StepUpBootstrapEligibilityQuery.call(actor: @actor)
        raise TokenStatusManagement::StepUpEvidenceUnavailable, "visitor Secret creation requires Step-Up"
      end

      return now
    end

    requirement = @step_up_requirement
    unless !@step_up_bootstrap && requirement.is_a?(StepUpRequirement) && requirement.step_up_required? &&
        requirement.scope == "settings_secret_credential" && requirement.actor_ref == @actor.public_id &&
        requirement.token_binding == @step_up_token.public_id && @step_up_token.active_status?(now) &&
        StepUpResolver.call(token: @step_up_token, requirement:, now:).satisfied?
      raise TokenStatusManagement::StepUpEvidenceUnavailable, "visitor Secret creation requires current Step-Up"
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
    VisitorSecretCredential.status_id_for(status)
  end
end
