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
    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock { apply_transition }
    end
  end

  private

  def apply_transition
    revoke_authentication_admissions!
    revoked_sessions = 0
    revoked_step_up = 0
    tokens = token_relation.to_a

    if revoke_step_up
      tokens.each do |token|
        revoked_step_up += revoke_step_up_for(token)
      end
    end

    tokens.each do |token|
      next unless revoke_session?(token)

      token.revoke!
      revoked_sessions += 1
    end

    record_audit!(revoked_sessions: revoked_sessions, revoked_step_up: revoked_step_up)
    Result.new(revoked_session_count: revoked_sessions, revoked_step_up_count: revoked_step_up)
  end

  def revoke_authentication_admissions!
    flow_model, ceremony_model, authorization_model =
      case actor
      when Client then [ClientSignInFlow, ClientAuthCeremonySession, ClientOidcAuthorizationTransaction]
      when Visitor then [VisitorSignInFlow, VisitorAuthCeremonySession, VisitorOidcAuthorizationTransaction]
      when Operator then [OperatorSignInFlow, OperatorAuthCeremonySession, OperatorOidcAuthorizationTransaction]
      else raise ArgumentError, "unsupported credential transition actor"
      end
    flow_model.connection_class_for_self.connected_to(role: :writing) do
      flow_model.transaction do
        references = ceremony_model.where(admission_purpose: %w(local_sign_in local_sign_up))
          .where.not(local_sign_in_flow_ref: nil).select(:local_sign_in_flow_ref)
        flows = flow_model.where(principal_id: actor.id, public_id: references, base_finalized_at: nil)
          .where.not(state_id: flow_model.state_ids_for("COMPLETED", "FAILED", "HALTED"))
        flows.lock.find_each do |flow|
          now = flow_model.database_now
          flow.halt_sign_in! unless flow.expired?(now)
          if flow.result_digest
            flow.update!(result_expires_at: [flow.result_expires_at, now].min)
          end
          ceremony_model.where(local_sign_in_flow_ref: flow.public_id).lock.find_each do |ceremony|
            ceremony.revoke!(now: ceremony_model.database_now) unless ceremony.terminal?
          end
        end
        expire_oidc_authentication!(authorization_model, ceremony_model)
      end
    end
  end

  def expire_oidc_authentication!(authorization_model, ceremony_model)
    authorization_model.where(actor_ref: actor.public_id, base_finalized_at: nil)
      .where.not(status: OidcAuthorizationTransactionable::STATUS_CONSUMED).lock.find_each do |transaction|
        now = authorization_model.database_now
        attributes = {
          expires_at: [transaction.expires_at, now].min,
          login_challenge_expires_at: [transaction.login_challenge_expires_at, now].min,
        }
        if transaction.result_expires_at
          attributes[:result_expires_at] = [transaction.result_expires_at, now].min
        end
        transaction.update!(attributes)
        if transaction.is_a?(ClientOidcAuthorizationTransaction)
          ClientSessionLimitResolutionTransaction.open
            .where(oidc_authorization_transaction_id: transaction.id).lock.find_each do |resolution|
              resolution.expire!
            end
        end
        ceremony_model.where(authorization_transaction_ref: transaction.transaction_id).lock.find_each do |ceremony|
          ceremony.revoke!(now: ceremony_model.database_now) unless ceremony.terminal?
        end
      end
  end

  private

  attr_reader :actor, :current_session, :reason, :affected_surface, :request, :revoke_current, :revoke_step_up,
              :revoke_other_sessions

  def validate!
    raise ArgumentError, "unsupported credential transition reason: #{reason.inspect}" unless REASONS.include?(reason)
    raise ArgumentError, "actor is required" if actor.blank?
    raise ArgumentError, "affected_surface is required" if affected_surface.blank?
    return if current_session.nil? || current_session_matches_actor?

    raise ArgumentError, "current session does not belong to the actor and surface"
  end

  def current_session_matches_actor?
    case [actor, current_session]
    in [Client, ClientToken] then current_session.user_id == actor.id
    in [Visitor, VisitorToken] then current_session.visitor_id == actor.id
    in [Operator, OperatorToken] then current_session.staff_id == actor.id
    else false
    end
  end

  def token_relation
    AuthenticationSessionRevoker.tokens_for(actor).not_revoked
  end

  def revoke_session?(token)
    same_token?(token, current_session) ? revoke_current : revoke_other_sessions
  end

  def same_token?(left, right)
    return false if left.nil? || right.nil?

    left.class == right.class && left.id == right.id
  end

  def revoke_step_up_for(token)
    had_freshness = token.respond_to?(:last_step_up_at) && token.last_step_up_at.present?
    IdentityStepUpCeremonyFreshnessRevoker.call!(token)
    had_freshness ? 1 : 0
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
