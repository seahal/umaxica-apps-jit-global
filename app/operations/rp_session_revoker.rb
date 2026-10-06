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
      # Token exchange and refresh rotation lock the stable Browser Session,
      # then its current root token, then the RP Session. `revoke!` applies the
      # same order and refuses a missing or ambiguous current token.
      session.revoke!(status: status, now: now)
    end
    1
  end

  def revoke_browser_session(token)
    return 0 if token.blank?

    with_writing_connection(token.class) do
      device_session = device_session_for(token)
      raise RpSession::IssuanceRejected, "Browser Session is missing" unless device_session

      # Lock the stable Browser Session first. The current root token and all
      # RP children are then observed under that same lock; a historical token
      # row is never treated as the session authority.
      device_session.with_lock do
        current_token = current_token_for(device_session)
        raise RpSession::IssuanceRejected, "Browser Session current root token is missing" unless current_token

        current_token.with_lock do
          sessions =
            rp_sessions_for(device_session)
              .currently_usable_at(now)
              .order(:id)
              .lock
              .to_a
          sessions.each { |session| session.revoke!(status: status, now: now) }
          revoke_parent_token!(current_token)
          sessions.size
        end
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

  def device_session_for(token)
    case token
    when ClientToken then ClientDeviceSession.find_by(id: token.device_session_id)
    when VisitorToken then VisitorDeviceSession.find_by(id: token.device_session_id)
    when OperatorToken then OperatorDeviceSession.find_by(id: token.device_session_id)
    else
      raise ArgumentError, "unsupported Base Browser Session class: #{token.class.name}"
    end
  end

  def current_token_for(device_session)
    case device_session
    when ClientDeviceSession then ClientToken.find_by(id: device_session.current_refresh_token_id)
    when VisitorDeviceSession then VisitorToken.find_by(id: device_session.current_refresh_token_id)
    when OperatorDeviceSession then OperatorToken.find_by(id: device_session.current_refresh_token_id)
    else
      raise ArgumentError, "unsupported Device Session class: #{device_session.class.name}"
    end
  end

  def rp_sessions_for(device_session)
    case device_session
    when ClientDeviceSession then ClientRpSession.where(device_session_id: device_session.id)
    when VisitorDeviceSession then VisitorRpSession.where(device_session_id: device_session.id)
    when OperatorDeviceSession then OperatorRpSession.where(device_session_id: device_session.id)
    else
      raise ArgumentError, "unsupported Device Session class: #{device_session.class.name}"
    end
  end
end
