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
                 step_up_evidence: nil, reason: "settings.session.revoke_others")
    @owner = owner
    @sessions = sessions
    @current_token = current_token
    @current_session_public_id = current_session_public_id
    @step_up_evidence = step_up_evidence
    @reason = reason
  end

  def call
    validate_binding!
    revoked = []
    now = current_token.class.database_now
    current_token.class.transaction do
      unless StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: owner, token: current_token)
        raise StepUpUnavailable, "Revoking other sessions requires current scoped Step-Up"
      end

      # Point-in-time (D-167): a session committed while this request waited for the lock is not
      # one the person asked to revoke.
      sessions.where(created_at: ..now).find_each do |token|
        result = AuthenticationSelectedSessionRevoker.call(
          owner: owner,
          token: token,
          current_token: current_token,
          current_session_public_id: current_session_public_id,
          reason: reason,
        )
        revoked.concat(result.revoked_tokens) if result.success?
      end
    end

    LogoutResult.success(revoked_tokens: revoked, message: :other_sessions_revoked)
  rescue TokenStatusManagement::StepUpEvidenceUnavailable
    raise StepUpUnavailable, "Revoking other sessions requires current scoped Step-Up"
  end

  private

  attr_reader :owner, :sessions, :current_token, :current_session_public_id, :step_up_evidence, :reason

  def validate_binding!
    now = current_token&.class&.database_now
    unless owner&.persisted? && current_token&.persisted? && token_belongs_to_owner? &&
        current_token.public_id == current_session_public_id && current_token.active_status?(now)
      raise Denied, "Revoking other sessions requires the current surface session"
    end
  end

  def token_belongs_to_owner?
    case [owner, current_token]
    in [Client, ClientToken] then current_token.user_id == owner.id
    in [Operator, OperatorToken] then current_token.staff_id == owner.id
    else false
    end
  end
end
