# typed: false
# frozen_string_literal: true

class AvatarAccessGrantResolver < ApplicationService
  GRANT_CLASSES = {
    "AvatarEnterpriseOwnershipPeriod" => [AvatarEnterprisePersonaGrant, :avatar_enterprise_ownership_period_id,
                                          :persona_public_id,],
    "AvatarBureauOwnershipPeriod" => [AvatarBureauAgentGrant, :avatar_bureau_ownership_period_id, :agent_public_id],
  }.freeze

  def initialize(avatar:, ownership_period:, subject:, capability:, at: Time.current)
    super()
    @avatar = avatar
    @ownership_period = ownership_period
    @subject = subject
    @capability = capability.to_s
    @at = at
  end

  public

  def call
    return false unless avatar.is_a?(Avatar) && ownership_period.respond_to?(:avatar_id)
    return false unless ownership_period.avatar_id == avatar.id
    return false unless ownership_period.current?

    grant_class, period_column, subject_column = GRANT_CLASSES[ownership_period.class.name]
    return false unless grant_class

    expected_subject = ownership_period.is_a?(AvatarEnterpriseOwnershipPeriod) ? ClientPersona : Agent
    return false unless subject.is_a?(expected_subject) && subject.public_id.present?
    return false if capability.blank?

    grant_class.active.effective_at(at).exists?(
      period_column => ownership_period.id,
      subject_column => subject.public_id,
      :capability => capability,
    )
  end

  private

  attr_reader :avatar, :ownership_period, :subject, :capability, :at
end
