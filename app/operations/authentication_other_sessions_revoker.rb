# typed: false
# frozen_string_literal: true

# "Revoke every session except the one making this request."
#
# Composed over `AuthenticationSelectedSessionRevoker` so the three browser
# surfaces share one definition of what revoking a single selected session
# means. The current session is skipped by the single-session primitive
# itself (it returns a `:current_session` failure), so callers do not need to
# filter the scope before handing it over.
class AuthenticationOtherSessionsRevoker
  class Denied < StandardError; end

  class StepUpUnavailable < Denied; end

  def self.call(...)
    new(...).call
  end

  def initialize(owner:, sessions:, current_token: nil, current_session_public_id: nil,
                 step_up_requirement:, reason: "settings.session.revoke_others")
    @owner = owner
    @sessions = sessions
    @current_token = current_token
    @current_session_public_id = current_session_public_id
    @step_up_requirement = step_up_requirement
    @reason = reason
  end

  def call
    validate_binding!
    revoked = []
    now = current_token.class.database_now
    current_token.class.transaction do
      current_token.with_lock do
        unless StepUpResolver.call(token: current_token, requirement: step_up_requirement, now:).satisfied?
          raise StepUpUnavailable, "Revoking other sessions requires current scoped Step-Up"
        end

        sessions.find_each do |token|
          result = AuthenticationSelectedSessionRevoker.call(
            owner: owner,
            token: token,
            current_token: current_token,
            current_session_public_id: current_session_public_id,
            reason: reason,
          )
          revoked.concat(result.revoked_tokens) if result.success?
        end

        if revoked.any?
          current_token.consume_step_up_evidence!(requirement: step_up_requirement, now:)
        end
      end
    end

    LogoutResult.success(revoked_tokens: revoked, message: :other_sessions_revoked)
  rescue TokenStatusManagement::StepUpEvidenceUnavailable
    raise StepUpUnavailable, "Revoking other sessions requires current scoped Step-Up"
  end

  private

  attr_reader :owner, :sessions, :current_token, :current_session_public_id, :step_up_requirement, :reason

  def validate_binding!
    now = current_token&.class&.database_now
    unless owner&.persisted? && current_token&.persisted? && token_belongs_to_owner? &&
        current_token.public_id == current_session_public_id && current_token.active_status?(now) &&
        valid_step_up_requirement?
      raise Denied, "Revoking other sessions requires the current surface session and Step-Up requirement"
    end
  end

  def token_belongs_to_owner?
    case [owner, current_token]
    in [Client, ClientToken] then current_token.user_id == owner.id
    in [Visitor, VisitorToken] then current_token.visitor_id == owner.id
    in [Operator, OperatorToken] then current_token.staff_id == owner.id
    else false
    end
  end

  def valid_step_up_requirement?
    surface =
      case owner
      when Client then "app"
      when Visitor then "com"
      when Operator then "org"
      end
    requirement = step_up_requirement
    requirement.is_a?(StepUpRequirement) && requirement.step_up_required? &&
      requirement.scope == "session_revoke_all" && requirement.purpose == "step_up" &&
      requirement.audience == "step_up:#{surface}" && requirement.actor_ref == owner.public_id &&
      requirement.session_binding == current_token.public_id && requirement.token_binding == current_token.public_id &&
      requirement.require_session_binding && requirement.ttl&.positive?
  end
end
