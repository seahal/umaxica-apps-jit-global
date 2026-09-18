# typed: false
# frozen_string_literal: true

class OidcRefreshTokenIssuer
  Resolved = Data.define(:usage, :verifier)

  Result =
    Data.define(:success, :token, :refresh_token, :previous_token, :reason) do
      def success? = success

      def [](key)
        public_send(key)
      end

      def fetch(key)
        value = self[key]
        return value unless value.nil?

        raise KeyError, "key not found: #{key.inspect}"
      end
    end

  def self.call(refresh_token:, client_id: nil, resource_type: nil)
    new(refresh_token, client_id: client_id, resource_type: resource_type).call
  end

  def self.resolve(refresh_token:, resource_type: nil)
    new(refresh_token, resource_type: resource_type).resolve
  end

  public

  def initialize(refresh_token, client_id: nil, resource_type: nil)
    @refresh_token = refresh_token
    @client_id = client_id
    @resource_type = resource_type.to_s
  end

  def resolve
    parsed = parse_refresh_token
    return unless parsed

    public_id, verifier = parsed
    usage = find_usage(public_id)
    return unless usage

    Resolved.new(usage: usage, verifier: verifier)
  end

  def call
    resolved = resolve
    return failure(:invalid_format) unless resolved

    usage = resolved.usage
    verifier = resolved.verifier

    # The lookup must run on the writing role. On a replica, replication lag can
    # return a pre-rotation row and re-accept a refresh token that was already
    # rotated away. docs/security/refresh-token-rotation.md requires the writing
    # role for exactly this reason.
    result = nil
    owner = connection_owner_for(usage.class)
    owner.connected_to(role: :writing) do
      parent = usage.parent_token
      return failure(:inactive_token, token: usage) unless parent

      # Browser-session revocation and first authorization-code exchange both
      # lock the parent before the RP child. Keep refresh rotation in the same
      # order so a revoke that has acquired the parent cannot be overtaken by a
      # child-only refresh lock.
      parent.with_lock do
        usage.with_lock do
          return failure(:client_mismatch, token: usage) if @client_id.present? && usage.oidc_client_id != @client_id

          # Check replay before activity: an attacker replaying a stolen token
          # after the legitimate client already rotated it must be detected even
          # once the usage has been revoked or has expired.
          if usage.previous_refresh_token_digest_matches?(verifier)
            handle_refresh_token_reuse(usage)
            return failure(:refresh_token_reuse_detected, token: usage)
          end

          return failure(:inactive_token, token: usage) unless usage.active?
          return failure(:invalid_digest, token: usage) unless usage.refresh_token_digest_matches?(verifier)

          previous_token = usage.dup
          refresh_token = usage.rotate_refresh_token!
          touch_oidc_connection!(usage)

          result = success(
            token: usage,
            refresh_token: refresh_token,
            previous_token: previous_token,
          )
        end
      end
    end

    result
  end

  private

  attr_reader :client_id, :resource_type

  def parse_refresh_token
    ClientToken.parse_refresh_token(@refresh_token)
  end

  # Each usage class lives on its own surface ticket database. The controller's
  # fixed endpoint realm must therefore select exactly one writing connection
  # and usage class before lookup; scanning all three surfaces would allow a
  # refresh request to cross the endpoint boundary before its realm check.
  def find_usage(public_id)
    context, usage_class = usage_context_and_class
    return unless context && usage_class

    context.connected_to(role: :writing) { usage_class.find_by(public_id: public_id) }
  end

  def usage_context_and_class
    case resource_type
    when "client" then [AppTicketRecord, ClientRpSession]
    when "operator" then [OrgTicketRecord, OperatorRpSession]
    when "visitor" then [ComTicketRecord, VisitorRpSession]
    end
  end

  # Reuse of an already-rotated refresh token is treated as compromise: the
  # usage is revoked so neither the legitimate client nor the attacker can
  # continue with it, and the event is recorded as data plus a redacted log
  # line. The raw verifier is never logged.
  def handle_refresh_token_reuse(usage)
    usage.revoke!(status: "failed") unless usage.revoked?

    parent = usage.parent_token
    actor_key = actor_identifier_key(parent)
    actor_id = actor_identifier(parent)

    if actor_key && actor_id
      SignRiskEmitter.emit(
        "refresh_reuse_detected",
        actor_key => actor_id,
        :user_token_id => usage.public_id,
      )
    end

    RefreshTokenReuseActivityRecorder.call(token: parent, result: "rp_session_revoked") if parent

    Rails.logger.info(
      JitLogEvent.format(
        "authentication.oidc_refresh.reuse_detected",
        rp_session_id: usage.public_id,
        oidc_client_id: usage.oidc_client_id,
        actor_type: parent&.class&.name,
        actor_id: actor_id,
      ),
    )
  end

  def actor_identifier_key(parent)
    case parent
    when ClientToken then :user_id
    when OperatorToken then :staff_id
    when VisitorToken then :visitor_id
    end
  end

  def actor_identifier(parent)
    case parent
    when ClientToken then parent.user_id
    when OperatorToken then parent.staff_id
    when VisitorToken then parent.visitor_id
    end
  end

  def touch_oidc_connection!(usage)
    connection = connection_for(usage)
    return unless connection

    connection.update!(last_used_at: Time.current)
  end

  def connection_for(usage)
    parent = usage.parent_token
    return nil unless parent

    case parent
    when ClientToken
      ClientOidcConnection.find_by(user_id: parent.user_id, client_id: usage.oidc_client_id)
    when OperatorToken
      OperatorOidcConnection.find_by(staff_id: parent.staff_id, client_id: usage.oidc_client_id)
    when VisitorToken
      VisitorOidcConnection.find_by(visitor_id: parent.visitor_id, client_id: usage.oidc_client_id)
    end
  end

  def connection_owner_for(klass)
    owner = klass
    owner = owner.superclass until owner.connection_class? || owner == ApplicationRecord
    owner
  end

  def success(token:, refresh_token:, previous_token:)
    Result.new(
      success: true,
      token: token,
      refresh_token: refresh_token,
      previous_token: previous_token,
      reason: nil,
    )
  end

  def failure(reason, token: nil)
    Result.new(
      success: false,
      token: token,
      refresh_token: nil,
      previous_token: nil,
      reason: reason,
    )
  end
end
