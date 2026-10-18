# typed: false
# frozen_string_literal: true

module SignUp
  class FinalizationPolicy < BasePolicy
    def finalize?
      mutable_ticket? &&
        at_step?("checkpoint") &&
        pending_actor_matches? &&
        all_requirements_clear?
    end

    private

    def all_requirements_clear?
      SignUpRequirementRegistry.for_ticket(
        ticket,
        surface: surface,
      ).missing_requirements(context.completed_requirements).empty?
    rescue ArgumentError
      false
    end
  end
end
