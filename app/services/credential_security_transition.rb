# typed: false
# frozen_string_literal: true

class CredentialSecurityTransition
  REASONS = %i(
    mfa_level_changed
    mfa_disabled
    mfa_reset
    password_changed
    email_address_verified
    recovery_codes_rotated
    api_token_created
    secret_credential_changed
  ).freeze

  Result = Data.define(:revoked_session_count, :revoked_step_up_count)

  def self.call(actor:, current_session:, reason:, affected_surface:, revoke_current: false,
                revoke_step_up: true, revoke_other_sessions: true, request: nil)
    new(
      actor: actor,
      current_session: current_session,
      reason: reason,
      affected_surface: affected_surface,
      revoke_current: revoke_current,
      revoke_step_up: revoke_step_up,
      revoke_other_sessions: revoke_other_sessions,
      request: request,
    ).call
  end

  def initialize(actor:, current_session:, reason:, affected_surface:, revoke_current:,
                 revoke_step_up:, revoke_other_sessions:, request:)
    @actor = actor
    @current_session = current_session
    @reason = reason.to_sym
    @affected_surface = affected_surface.to_s
    @revoke_current = revoke_current
    @revoke_step_up = revoke_step_up
    @revoke_other_sessions = revoke_other_sessions
    @request = request
  end

  def call
    validate!

    revoked_sessions = 0
    revoked_step_up = 0
    tokens = revoke_step_up ? token_relation.includes(:step_up_session).to_a : token_relation.to_a

    tokens.each do |token|
      next if keep_current_session?(token)

      token.revoke! if revoke_session?(token)
      revoked_sessions += 1
    end

    if revoke_step_up
      tokens.each do |token|
        revoked_step_up += revoke_step_up_for(token)
      end
    end

    record_audit!(revoked_sessions: revoked_sessions, revoked_step_up: revoked_step_up)
    Result.new(revoked_session_count: revoked_sessions, revoked_step_up_count: revoked_step_up)
  end

  private

  attr_reader :actor, :current_session, :reason, :affected_surface, :request, :revoke_current, :revoke_step_up,
              :revoke_other_sessions

  def validate!
    raise ArgumentError, "unsupported credential transition reason: #{reason.inspect}" unless REASONS.include?(reason)
    raise ArgumentError, "actor is required" if actor.blank?
    raise ArgumentError, "affected_surface is required" if affected_surface.blank?
  end

  def token_relation
    AuthenticationSessionRevoker.tokens_for(actor).not_revoked
  end

  def keep_current_session?(token)
    !revoke_current && same_token?(token, current_session)
  end

  def revoke_session?(token)
    revoke_current || revoke_other_sessions || !same_token?(token, current_session)
  end

  def same_token?(left, right)
    return false if left.blank? || right.blank?
    return left.id == right.id if left.respond_to?(:id) && right.respond_to?(:id)

    false
  end

  def revoke_step_up_for(token)
    had_freshness = token.respond_to?(:last_step_up_at) && token.last_step_up_at.present?
    IdentityStepUpCeremonyFreshnessRevoker.call!(token) if had_freshness
    revoke_step_up_session_record!(token)
    had_freshness ? 1 : 0
  end

  def revoke_step_up_session_record!(token)
    return unless token.respond_to?(:step_up_session)

    session = token.step_up_session
    return if session.blank? || session.expired?

    session.update!(discard_at: Time.current)
  end

  def record_audit!(revoked_sessions:, revoked_step_up:)
    IdentityAudit.record!(
      actor: actor,
      event_id: audit_event_id,
      action: "credential_security_transition.#{reason}",
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent,
      metadata: {
        reason: reason.to_s,
        surface: affected_surface,
        current_session_retained: !revoke_current,
        revoked_session_count: revoked_sessions,
        revoked_step_up_count: revoked_step_up,
        request_id: request&.request_id,
      }.compact,
    )
  end

  def audit_event_id
    return OperatorChronicleEvent::CREDENTIAL_SECURITY_TRANSITION if actor.is_a?(Operator)

    ClientChronicleEvent::CREDENTIAL_SECURITY_TRANSITION
  end
end
