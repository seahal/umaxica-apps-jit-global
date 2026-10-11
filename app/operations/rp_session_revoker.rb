# typed: false
# frozen_string_literal: true

# Explicit revoke scopes for the Identity -> Base Browser Session -> RP Session
# hierarchy. Child revoke stops refresh and new issuance for that RP only; it
# does not invalidate sibling RP Sessions or already-issued Access JWTs.
class RpSessionRevoker < ApplicationService
  Result =
    Data.define(:success, :revoked_count) do
      def success? = success
    end

  public

  def initialize(scope:, record:, status: "failed", now: Time.current)
    super()
    @scope = scope.to_sym
    @record = record
    @status = status
    @now = now
  end

  def call
    count =
      case scope
      when :rp_session
        revoke_rp_session(record)
      when :browser_session
        revoke_browser_session(record)
      when :identity
        revoke_identity(record)
      else
        raise ArgumentError, "unsupported RP Session revoke scope: #{scope.inspect}"
      end

    Result.new(success: true, revoked_count: count)
  end

  private

  attr_reader :scope, :record, :status, :now

  def revoke_rp_session(session)
    return 0 if session.blank? || session.revoked?

    with_writing_connection(session.class) do
      parent = session.parent_token
      return 0 if parent.blank?

      # Token exchange and refresh rotation lock the Browser Session before
      # the RP Session. Keep the child-only revoke in that order so a revoke
      # cannot race a first exchange or a refresh that already owns the parent.
      parent.with_lock do
        session.with_lock do
          return 0 if session.revoked?

          session.revoke!(status: status, now: now)
        end
      end
    end
    1
  end

  def revoke_browser_session(token)
    return 0 if token.blank?

    with_writing_connection(token.class) do
      association = rp_sessions_association_for(token)

      # Token exchange locks the parent before it looks up or creates an RP
      # Session. Keep browser-session revocation in that same order; locking a
      # child first can deadlock when an exchange already owns the parent and is
      # waiting for that child. The ordered child lock also makes concurrent
      # multi-child revocations deterministic.
      token.with_lock do
        sessions =
          token.public_send(association)
            .currently_usable_at(now)
            .order(:id)
            .lock
            .to_a
        sessions.each { |session| session.revoke!(status: status, now: now) }
        revoke_parent_token!(token)
        sessions.size
      end
    end
  end

  def revoke_identity(browser_sessions)
    unless browser_sessions.respond_to?(:each)
      raise ArgumentError, "identity revoke requires an enumerable of Base Browser Sessions"
    end

    browser_sessions.sum { |browser_session| revoke_browser_session(browser_session) }
  end

  def revoke_parent_token!(token)
    if token.respond_to?(:revoke!)
      token.revoke! unless token.respond_to?(:revoked?) && token.revoked?
      return
    end

    return unless token.respond_to?(:discard)
    return if token.respond_to?(:discarded?) && token.discarded?

    token.discard
  end

  def with_writing_connection(klass, &)
    owner = connection_owner_for(klass)
    return yield if owner.blank?

    owner.connected_to(role: :writing, &)
  end

  def connection_owner_for(klass)
    return unless klass.respond_to?(:connection_class?)

    owner = klass
    owner = owner.superclass until owner.connection_class? || owner == ApplicationRecord
    owner
  end

  def rp_sessions_association_for(token)
    case token
    when ClientToken then :client_rp_sessions
    when VisitorToken then :visitor_rp_sessions
    when OperatorToken then :operator_rp_sessions
    else
      raise ArgumentError, "unsupported Base Browser Session class: #{token.class.name}"
    end
  end
end
