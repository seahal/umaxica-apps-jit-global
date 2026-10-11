# typed: false
# frozen_string_literal: true

module AvatarAccessGrants
  class IssueOperation < ApplicationService
    GRANT_CLASSES = {
      "AvatarEnterpriseOwnershipPeriod" => AvatarEnterprisePersonaGrant,
      "AvatarBureauOwnershipPeriod" => AvatarBureauAgentGrant,
    }.freeze

    def initialize(ownership_period:, subject:, capability:, granted_by_actor_public_id:,
                   granted_at: Avatar.database_now)
      super()
      @ownership_period = ownership_period
      @subject = subject
      @capability = capability.to_s
      @granted_by_actor_public_id = granted_by_actor_public_id.to_s
      @granted_at = granted_at
    end

    public

    def call
      validate_inputs!
      grant_class = GRANT_CLASSES.fetch(ownership_period.class.name)

      AvatarRecord.transaction(requires_new: true) do
        locked_period = ownership_period.class.lock.find(ownership_period.id)
        raise ArgumentError, "access grants require the current ownership period" unless locked_period.current?

        grant_class.create!(
          :ownership_period => locked_period,
          subject_attributes => subject.public_id,
          :capability => capability,
          :granted_by_actor_public_id => granted_by_actor_public_id,
          :granted_by_surface => authority_surface,
          :granted_at => granted_at,
        )
      end
    end

    private

    attr_reader :ownership_period, :subject, :capability, :granted_by_actor_public_id, :granted_at

    def validate_inputs!
      unless GRANT_CLASSES.key?(ownership_period.class.name)
        raise ArgumentError, "unsupported ownership period for access grant"
      end

      expected_subject = ownership_period.is_a?(AvatarEnterpriseOwnershipPeriod) ? ClientPersona : Agent
      raise ArgumentError, "subject must be a concrete supported identity" unless subject.is_a?(expected_subject)
      raise ArgumentError, "subject public id is required" if subject.public_id.blank?
      raise ArgumentError, "capability is required" if capability.blank?
      raise ArgumentError, "granting actor public id is required" if granted_by_actor_public_id.blank?
      raise ArgumentError, "granted_at is required" if granted_at.blank?
    end

    def subject_attributes
      ownership_period.is_a?(AvatarEnterpriseOwnershipPeriod) ? :persona_public_id : :agent_public_id
    end

    def authority_surface
      ownership_period.is_a?(AvatarEnterpriseOwnershipPeriod) ? "app" : "org"
    end
  end
end
