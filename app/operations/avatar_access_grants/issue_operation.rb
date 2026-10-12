# typed: false
# frozen_string_literal: true

module AvatarAccessGrants
  class IssueOperation < ApplicationService
    GRANT_CLASSES = {
      "AvatarEnterpriseOwnershipPeriod" => AvatarEnterprisePersonaGrant,
      "AvatarBureauOwnershipPeriod" => AvatarBureauAgentGrant,
    }.freeze

    def initialize(ownership_period:, subject:, capability:, granted_by_actor_public_id:,
                   granting_subject_public_id:,
                   granted_at: Avatar.database_now)
      super()
      @ownership_period = ownership_period
      @subject = subject
      @capability = capability.to_s
      @granted_by_actor_public_id = granted_by_actor_public_id.to_s
      @granting_subject_public_id = granting_subject_public_id.to_s
      @granted_at = granted_at
    end

    public

    def call
      validate_inputs!
      grant_class = GRANT_CLASSES.fetch(ownership_period.class.name)

      with_authorized_granting_actor do
        AvatarRecord.transaction(requires_new: true) do
          locked_period = ownership_period.class.lock.find(ownership_period.id)
          unless locked_period.current? &&
              ownership_collective_public_id == locked_period_collective_public_id(locked_period)
            raise ArgumentError, "access grants require the current ownership period"
          end

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
    end

    private

    attr_reader :ownership_period, :subject, :capability, :granted_by_actor_public_id,
                :granting_subject_public_id, :granted_at

    def validate_inputs!
      unless GRANT_CLASSES.key?(ownership_period.class.name)
        raise ArgumentError, "unsupported ownership period for access grant"
      end

      expected_subject = ownership_period.is_a?(AvatarEnterpriseOwnershipPeriod) ? ClientPersona : Agent
      raise ArgumentError, "subject must be a concrete supported identity" unless subject.is_a?(expected_subject)
      raise ArgumentError, "subject public id is required" if subject.public_id.blank?
      raise ArgumentError, "capability is required" if capability.blank?
      raise ArgumentError, "granting actor public id is required" if granted_by_actor_public_id.blank?
      raise ArgumentError, "granting subject public id is required" if granting_subject_public_id.blank?
      raise ArgumentError, "granted_at is required" if granted_at.blank?
    end

    def subject_attributes
      ownership_period.is_a?(AvatarEnterpriseOwnershipPeriod) ? :persona_public_id : :agent_public_id
    end

    def authority_surface
      ownership_period.is_a?(AvatarEnterpriseOwnershipPeriod) ? "app" : "org"
    end

    def ownership_collective_public_id
      locked_period_collective_public_id(ownership_period)
    end

    def locked_period_collective_public_id(period)
      case period
      when AvatarEnterpriseOwnershipPeriod then period.enterprise_public_id.to_s
      when AvatarBureauOwnershipPeriod then period.bureau_public_id.to_s
      else raise ArgumentError, "unsupported ownership period for access grant"
      end
    end

    def granting_actor
      actor =
        case authority_surface
        when "app" then Client.find_by(public_id: granted_by_actor_public_id)
        when "org" then Operator.find_by(public_id: granted_by_actor_public_id)
        else raise ArgumentError, "unsupported granting surface"
        end
      return actor if actor

      raise AvatarOwnerMembershipLockService::AuthorizationDenied, "granting actor was not found"
    end

    def with_authorized_granting_actor
      AvatarOwnerMembershipLockService.call(
        actor: granting_actor,
        surface: authority_surface,
        subject_public_id: granting_subject_public_id,
        owner_collective_public_id: ownership_collective_public_id,
        permission: "avatar.grant.manage",
        avatar: ownership_period.avatar,
      ) { yield }
    end
  end
end
