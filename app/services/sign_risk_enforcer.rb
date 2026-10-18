# typed: false
# frozen_string_literal: true

class SignRiskEnforcer
  # resource: The user/staff record (ActiveRecord)
  def self.call(resource)
    return unless feature_enabled?
    return unless resource

    score =
      if resource.respond_to?(:staff_tokens)
        SignRiskEngine.score(staff_id: resource.id)
      else
        SignRiskEngine.score(user_id: resource.id)
      end

    if score >= 100
      revoke!(resource)
    elsif score >= 60
      require_step_up!(resource)
    end
  end

  def self.revoke!(resource)
    revoke_token_set(resource.client_tokens) if resource.respond_to?(:client_tokens)
    revoke_token_set(resource.staff_tokens) if resource.respond_to?(:staff_tokens)
  end

  def self.revoke_token_set(tokens)
    tokens.currently_usable_at.find_each do |token|
      AuthenticationLogoutCurrentSession.call(
        resource: token.actor_record,
        token: token,
        reason: "sign_risk",
      )
    end
  end

  def self.require_step_up!(resource)
    require_step_up_for_token_set(resource.client_tokens) if resource.respond_to?(:client_tokens)
    require_step_up_for_token_set(resource.staff_tokens) if resource.respond_to?(:staff_tokens)

    Rails.logger.info(
      JitLogEvent.format(
        "sign.risk.enforcer.step_up_required",
        resource_type: resource.class.name,
        resource_id: resource.id,
      ),
    )
  end

  # Risk-triggered force re-step-up. acme/www owns freshness mutation.
  def self.require_step_up_for_token_set(tokens)
    tokens.currently_usable_at.find_each do |token|
      IdentityStepUpCeremonyFreshnessRevoker.call!(token)
    end
  end

  def self.feature_enabled?
    return false if ENV["RISK_ENFORCEMENT_DISABLED"] == "true"

    enabled_config = Rails.configuration.try(:x).try(:risk_enforcement).try(:enabled)
    enabled_config || ENV["RISK_ENFORCEMENT_ENABLED"] == "true" || Rails.env.production?
  end

  private_class_method :revoke_token_set, :require_step_up_for_token_set
end
