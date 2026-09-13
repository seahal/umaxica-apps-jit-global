# typed: false
# frozen_string_literal: true

class OidcRefreshTokenIssuer
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

  def self.call(refresh_token:)
    new(refresh_token).call
  end

  def initialize(refresh_token)
    @refresh_token = refresh_token
  end

  def call
    parsed = parse_refresh_token
    return failure(:invalid_format) unless parsed

    public_id, verifier = parsed

    # The lookup must run on the writing role. On a replica, replication lag can
    # return a pre-rotation row and re-accept a refresh token that was already
    # rotated away. docs/security/refresh-token-rotation.md requires the writing
    # role for exactly this reason.
    usage = find_usage(public_id)
    return failure(:token_not_found) unless usage

    result = nil
    owner = connection_owner_for(usage.class)
    owner.connected_to(role: :writing) do
      usage.with_lock do
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

    result
  end

  private

  def parse_refresh_token
    ClientToken.parse_refresh_token(@refresh_token)
  end

  # Each usage class lives on its own surface ticket database, so the writing
  # role has to be selected per connection class rather than once around the
  # whole lookup.
  def find_usage(public_id)
    AppTicketRecord.connected_to(role: :writing) do
      ClientTokenUsage.find_by(public_id: public_id)
    end || OrgTicketRecord.connected_to(role: :writing) do
      OperatorTokenUsage.find_by(public_id: public_id)
    end || ComTicketRecord.connected_to(role: :writing) do
      VisitorTokenUsage.find_by(public_id: public_id)
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

    RefreshTokenReuseActivityRecorder.call(token: parent, result: "token_usage_revoked") if parent

    Rails.logger.info(
      JitLogEvent.format(
        "authentication.oidc_refresh.reuse_detected",
        token_usage_id: usage.public_id,
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
