# typed: false
# frozen_string_literal: true

module SignUp
  class RequirementPolicy < BasePolicy
    def clear_requirement?
      mutable_ticket? &&
        at_step?("checkpoint") &&
        pending_actor_matches? &&
        requirement_belongs_to_ticket? &&
        requirement_still_pending?
    end

    def continue_after_cleared_requirement?
      mutable_ticket? &&
        at_step?("checkpoint") &&
        pending_actor_matches? &&
        requirement_belongs_to_ticket? &&
        requirement_cleared?
    end

    def clear_birthdate?
      clear_named_requirement?(:birthdate)
    end

    def register_passkey?
      clear_named_requirement?(:passkey)
    end

    private

    def clear_named_requirement?(requirement)
      clear_requirement? && context.requirement == requirement
    end

    def requirement_belongs_to_ticket?
      SignUpRequirementRegistry.for_ticket(ticket, surface: surface).requirement?(context.requirement)
    rescue ArgumentError
      false
    end

    def requirement_still_pending?
      registry = SignUpRequirementRegistry.for_ticket(ticket, surface: surface)
      !registry.requirement_cleared?(ticket.completed_requirements, context.requirement)
    rescue ArgumentError
      false
    end

    def requirement_cleared?
      registry = SignUpRequirementRegistry.for_ticket(ticket, surface: surface)
      registry.requirement_cleared?(ticket.completed_requirements, context.requirement)
    rescue ArgumentError
      false
    end
  end
end
