# typed: false
# frozen_string_literal: true

module SignUp
  class TicketPolicy < BasePolicy
    def start?
      !signed_in?
    end

    def resume?
      show?
    end

    def show?
      mutable_ticket?
    end

    def submit_contact?
      mutable_ticket? && at_step?("start")
    end

    def verify_contact?
      mutable_ticket? && at_step?("contact")
    end

    def enter_guardrail?
      mutable_ticket? && at_step?("contact_verified")
    end

    def enter_checkpoint?
      mutable_ticket? && at_step?("guardrail")
    end

    def clear_requirement?
      mutable_ticket? && at_step?("checkpoint") && pending_actor_matches?
    end

    def finalize?
      mutable_ticket? && at_step?("checkpoint") && pending_actor_matches?
    end

    def handoff_to_sign_in?
      mutable_ticket? && at_step?("finalized") && pending_actor_matches?
    end

    def cancel?
      surface_matches? &&
        sequence_bound? &&
        !signed_in? &&
        ticket.respond_to?(:sign_up_cancelable?) &&
        (ticket.sign_up_cancelable? || ticket.sign_up_cancelled?)
    end
  end
end
