# typed: false
# frozen_string_literal: true

# "Revoke every active session for this actor."
#
# Built as a composition over the single-session primitive
# `AuthenticationLogoutCurrentSession`. The contract is:
#
#   "delete all sessions" = repeat ("delete one session") over the actor's
#                            token scope.
#
# Why composition (not a parallel implementation):
#   - There must be a single chokepoint that knows what "revoke one
#     session" means (set discard_at, write status, etc.). If we had
#     two independent implementations they would drift.
#   - It keeps the failure semantics of single-revoke consistent across
#     callers (current-session logout, bulk revoke, lifecycle suspend).
#
# This service handles the *batch-level* concerns that don't belong to a
# single revoke: bumping `session_version` so still-valid JWTs are
# rejected at refresh time, and emitting a batch failure event when an
# individual revoke escapes the primitive's narrow rescue.
class AuthenticationLogoutAllSessions
  def self.call(...)
    new(...).call
  end

  def initialize(resource: nil, user: nil, visitor: nil, operator: nil, rp_account: nil, reason: "logout_all")
    @resource = resource || user || visitor || operator || rp_account
    @reason = reason
  end

  def call
    increment_session_version_if_present!
    each_token { |token| revoke_one!(token) }
    true
  end

  private

  attr_reader :resource, :reason

  def increment_session_version_if_present!
    return unless resource&.respond_to?(:session_version)

    resource.session_version = resource.session_version.to_i + 1
    resource.save!
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.info(
      JitLogEvent.format(
        "auth.logout_all_sessions.session_version_failed",
        reason: reason,
        resource_class: resource&.class&.name,
        resource_id: resource&.id,
        error_class: e.class.name,
        error_message: e.message,
      ),
    )
  end

  def each_token
    scope = token_scope
    return if scope.blank?

    scope.find_each { |token| yield token }
  end

  def token_scope
    case resource&.class&.name
    when "Client"
      return ClientToken.where(user_id: resource.id).includes(:device_session)
    when "Visitor"
      return VisitorToken.where(visitor_id: resource.id).includes(:device_session)
    when "Operator"
      return OperatorToken.where(staff_id: resource.id).includes(:device_session)
    end

    nil
  end

  # Delegate the actual revoke to the single-session primitive so the two
  # paths stay in lock-step.
  def revoke_one!(token)
    AuthenticationLogoutCurrentSession.call(
      resource: resource,
      token: token,
      token_class: token&.class,
      session_public_id: token.respond_to?(:public_id) ? token.public_id : nil,
      reason: reason,
      cascade_device_session_tokens: false,
    )
  rescue ActiveRecord::ActiveRecordError => e
    # Net for anything escaping the primitive's narrower rescue
    # (e.g. ConnectionNotEstablished). Surfaced under a batch-specific
    # event name so operators can distinguish "one token failed inside
    # a bulk revoke" from "the only session-revoke failed".
    Rails.logger.info(
      JitLogEvent.format(
        "auth.logout_all_sessions.token_failed",
        reason: reason,
        resource_class: resource&.class&.name,
        resource_id: resource&.id,
        token_class: token&.class&.name,
        token_id: token&.try(:public_id),
        error_class: e.class.name,
        error_message: e.message,
      ),
    )
    true
  end
end
