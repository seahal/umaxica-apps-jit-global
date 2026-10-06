# typed: false
# frozen_string_literal: true

module SignIn
  class CyclePolicy < ApplicationPolicy
    def show_primary?
      status_allowed?("PRIMARY_PENDING", actor_required: actor_bound?, token_required: token_bound?)
    end

    def verify_primary?
      status_allowed?("PRIMARY_PENDING", actor_required: actor_bound?, token_required: token_bound?)
    end

    def show_mfa?
      status_allowed?("MFA_PENDING", actor_required: true)
    end

    def verify_mfa?
      status_allowed?("MFA_PENDING", actor_required: true)
    end

    def run_guardrail?
      status_allowed?("GUARDRAIL_PENDING", actor_required: actor_bound?, token_required: token_bound?)
    end

    def issue_session?
      status_allowed?("SESSION_ISSUANCE_PENDING", actor_required: true)
    end

    def show_checkpoint?
      status_allowed?("CHECKPOINT_PENDING")
    end

    def complete_checkpoint?
      show_checkpoint?
    end

    def show_selector?
      status_allowed?("SELECTOR_PENDING")
    end

    def fail?
      return false unless sign_in_flow?
      return false if terminal?
      return false if actor_bound? && !actor_matches?
      return false if token_bound? && !token_matches?

      true
    end

    private

    def status_allowed?(status_name, actor_required: false, token_required: false)
      return false unless sign_in_flow?
      return false unless record.state_id == record.state_id_for(status_name)
      return false if terminal?
      return false if actor_required && !actor_matches?
      return false if token_required && !token_matches?

      true
    end

    def sign_in_flow?
      record.respond_to?(:state_id_for) &&
        record.respond_to?(:sign_in_completed?) &&
        record.respond_to?(:sign_in_failed?)
    end

    def terminal?
      record.sign_in_completed? || record.sign_in_failed?
    end

    def actor_bound?
      record.respond_to?(:principal_id) && record.principal_id.present?
    end

    def token_bound?
      record.respond_to?(:token_id) && record.token_id.present?
    end

    def actor_matches?
      return false unless user
      return true unless actor_bound?

      user.id == record.principal_id && actor_class_matches?
    end

    def token_matches?
      return false unless token_bound?

      current_public_id = Actor.authn.login_public_id
      return false if current_public_id.blank?

      token = record.token
      token&.public_id == current_public_id || token&.try(:device_session)&.public_id == current_public_id
    end

    def actor_class_matches?
      case record
      when ClientSignInFlow then user.is_a?(Client)
      when VisitorSignInFlow then user.is_a?(Visitor)
      when OperatorSignInFlow then user.is_a?(Operator)
      else false
      end
    end
  end
end
