# typed: false
# frozen_string_literal: true

module SignUp
  class ParticipantPolicy < BasePolicy
    def enter_guardrail?
      mutable_ticket? && at_step?("contact_verified")
    end

    def enter_checkpoint?
      mutable_ticket? && at_step?("guardrail", "checkpoint")
    end
  end
end
