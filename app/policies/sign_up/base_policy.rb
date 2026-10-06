# typed: false
# frozen_string_literal: true

module SignUp
  class BasePolicy < ApplicationPolicy
    private

    def context
      record
    end

    def ticket
      record.respond_to?(:ticket) ? record.ticket : record
    end

    def actor_authentication
      record.respond_to?(:actor_authentication) ? record.actor_authentication : nil
    end

    def surface
      if record.respond_to?(:surface)
        record.surface.to_sym
      else
        SignUpRequirementRegistry.surface_for_ticket(ticket)
      end
    end

    def signed_in?
      return true if user.present?
      return false unless actor_authentication.respond_to?(:signed_in?)

      actor_authentication.signed_in?
    end

    def valid_ticket?
      ticket.present? &&
        ticket.respond_to?(:public_id) &&
        ticket.respond_to?(:status_id) &&
        ticket.respond_to?(:status_id_for)
    end

    def surface_matches?
      valid_ticket? && SignUpRequirementRegistry.surface_for_ticket(ticket) == surface
    rescue ArgumentError
      false
    end

    def sequence_bound?
      return false unless valid_ticket?
      return false unless actor_authentication.respond_to?(:active_sign_sequence_id)

      ActiveSupport::SecurityUtils.secure_compare(
        actor_authentication.active_sign_sequence_id.to_s,
        ticket.public_id.to_s,
      )
    end

    def mutable_ticket?
      surface_matches? && sequence_bound? && !signed_in? && !terminal? && !expired?
    end

    def expired?
      ticket.respond_to?(:expired?) && ticket.expired?
    end

    def terminal?
      terminal_status_ids.include?(ticket.status_id)
    end

    def terminal_status_ids
      %w(COMPLETED FAILED EXPIRED CANCELLED HALTED).filter_map do |status_name|
        ticket.status_id_for(status_name)
      rescue KeyError
        nil
      end
    end

    def at_step?(*steps)
      steps.map(&:to_s).include?(ticket.step.to_s)
    end

    def pending_actor_matches?
      return true if ticket.principal_id.blank?
      return pending_actor.id == ticket.principal_id if pending_actor.present?
      return false unless user

      user.id == ticket.principal_id && actor_class_matches?
    end

    def pending_actor
      record.respond_to?(:pending_actor) ? record.pending_actor : nil
    end

    def actor_class_matches?
      case ticket
      when ClientSignUpFlow then user.is_a?(Client)
      when VisitorSignUpFlow then user.is_a?(Visitor)
      else false
      end
    end
  end
end
