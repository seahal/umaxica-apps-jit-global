# typed: false
# frozen_string_literal: true

class OidcRefreshTokenIssuer
  Resolved = Data.define(:usage, :verifier)

  Result =
    Data.define(
      :success, :token, :refresh_token, :previous_token, :reason, :token_response,
      :access_expires_at, :refresh_expires_at,
    ) do
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

  def self.call(refresh_token:, client_id: nil, resource_type: nil, response_builder: nil, coordination_store: nil)
    new(
      refresh_token,
      client_id: client_id,
      resource_type: resource_type,
      response_builder: response_builder,
      coordination_store: coordination_store,
    ).call
  end

  def self.resolve(refresh_token:, resource_type: nil)
    new(refresh_token, resource_type: resource_type).resolve
  end

  public

  def initialize(refresh_token, client_id: nil, resource_type: nil, response_builder: nil, coordination_store: nil)
    @refresh_token = refresh_token
    @client_id = client_id
    @resource_type = resource_type.to_s
    @response_builder = response_builder
    @coordination_store = coordination_store
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

    return call_with_delivery(resolved) if response_builder

    rotate_without_delivery(resolved)
  end

  private

  attr_reader :client_id, :resource_type, :response_builder

  def rotate_without_delivery(resolved)

    usage = resolved.usage
    verifier = resolved.verifier

    # The lookup must run on the writing role. On a replica, replication lag can
    # return a pre-rotation row and re-accept a refresh token that was already
    # rotated away. docs/security/refresh-token-rotation.md requires the writing
    # role for exactly this reason.
    result = nil
    owner = connection_owner_for(usage.class)
    owner.connected_to(role: :writing) do
      usage.with_parent_and_self_lock do
        return failure(:client_mismatch, token: usage) if @client_id.present? && usage.oidc_client_id != @client_id

        # Check replay before activity: an attacker replaying a stolen token
        # after the legitimate client already rotated it must be detected even
        # once the usage has been revoked or has expired.
        if usage.previous_refresh_token_digest_matches?(verifier)
          handle_refresh_token_reuse(usage)
          return failure(:refresh_token_reuse_detected, token: usage)
        end

        decision_time = usage.class.database_now
        return failure(:inactive_token, token: usage) unless usage.active?(decision_time)
        return failure(:invalid_digest, token: usage) unless usage.refresh_token_digest_matches?(verifier)

        previous_token = usage.dup
        refresh_token = usage.rotate_refresh_token!(now: decision_time)
        touch_oidc_connection!(usage, now: decision_time)

        result = success(
          token: usage,
          refresh_token: refresh_token,
          previous_token: previous_token,
        )
      end
    end

    result
  end

  def call_with_delivery(resolved)
    usage = resolved.usage
    verifier = resolved.verifier
    predecessor_digest = encoded_refresh_token_digest(usage, verifier)
    lookup = delivery_lookup(usage, predecessor_digest)
    return failure(:delivery_receipt_invalid, token: usage) if lookup.status == :invalid

    if lookup.receipt
      redelivery = redeliver_receipt(usage, predecessor_digest)
      return redelivery if redelivery
    end

    store = coordination_store
    owner = SecureRandom.uuid
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + OidcRefreshDeliveryReceipt::TTL.to_f

    loop do
      if store.acquire(resource_type:, rp_session_public_id: usage.public_id, owner:)
        begin
          result = rotate_with_delivery(usage, verifier, predecessor_digest)
          result = publish_delivery!(store, usage, result) if result.success?
          return result
        ensure
          release_delivery_lease(store, usage, owner)
        end
      end

      usage = reload_usage(usage)
      lookup = delivery_lookup(usage, predecessor_digest)
      return failure(:delivery_receipt_invalid, token: usage) if lookup.status == :invalid

      if lookup.receipt
        redelivery = redeliver_receipt(usage, predecessor_digest)
        return redelivery if redelivery
      end

      return failure(:coordination_timeout, token: usage) if
        Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.01
    end
  end

  def rotate_with_delivery(usage, verifier, predecessor_digest)
    result = nil
    owner = connection_owner_for(usage.class)
    owner.connected_to(role: :writing) do
      usage.with_parent_and_self_lock do
        usage.class.uncached { usage.reload }
        return failure(:client_mismatch, token: usage) if client_id.present? && usage.oidc_client_id != client_id

        decision_time = usage.class.database_now
        lookup = delivery_lookup(usage, predecessor_digest, now: decision_time)
        return failure(:delivery_receipt_invalid, token: usage) if lookup.status == :invalid

        if lookup.receipt
          return failure(:inactive_token, token: usage) unless usage.active?(decision_time)

          response = lookup.receipt.token_response_for(now: decision_time)
          return success(
            token: usage,
            refresh_token: response.fetch(:refresh_token),
            previous_token: nil,
            token_response: response,
            access_expires_at: lookup.receipt.access_expires_at,
            refresh_expires_at: lookup.receipt.refresh_expires_at,
          )
        end
        usage.clear_refresh_delivery_receipt! if lookup.status == :expired

        if usage.previous_refresh_token_digest_matches?(verifier)
          handle_refresh_token_reuse(usage)
          return failure(:refresh_token_reuse_detected, token: usage)
        end

        return failure(:inactive_token, token: usage) unless usage.active?(decision_time)
        return failure(:invalid_digest, token: usage) unless usage.refresh_token_digest_matches?(verifier)

        previous_token = usage.dup
        refresh_plain = usage.rotate_refresh_token!(now: decision_time)
        token_response = response_builder.call(
          usage: usage,
          previous_token: previous_token,
          refresh_token: refresh_plain,
          predecessor_digest: predecessor_digest,
          now: decision_time,
        )
        receipt_expires_at = decision_time + OidcRefreshDeliveryReceipt::TTL
        access_expires_at = decision_time + response_seconds(token_response, :expires_in).seconds
        ciphertext = OidcRefreshDeliveryReceipt.encrypt(
          rp_session_public_id: usage.public_id,
          client_id: client_id,
          resource_type: resource_type,
          predecessor_digest: predecessor_digest,
          generation: usage.refresh_generation,
          expires_at: receipt_expires_at,
          access_expires_at: access_expires_at,
          refresh_expires_at: usage.refresh_token_expires_at,
          token_response: token_response,
        )
        usage.store_refresh_delivery_receipt!(
          ciphertext: ciphertext,
          predecessor_digest: predecessor_digest,
          expires_at: receipt_expires_at,
        )
        touch_oidc_connection!(usage, now: decision_time)

        result = success(
          token: usage,
          refresh_token: refresh_plain,
          previous_token: previous_token,
          token_response: token_response,
          access_expires_at: access_expires_at,
          refresh_expires_at: usage.refresh_token_expires_at,
        )
      end
    end
    result
  end

  def redeliver_receipt(usage, predecessor_digest)
    result = nil
    owner = connection_owner_for(usage.class)
    owner.connected_to(role: :writing) do
      usage.with_parent_and_self_lock do
        usage.class.uncached { usage.reload }
        decision_time = usage.class.database_now
        lookup = delivery_lookup(usage, predecessor_digest, now: decision_time)
        return failure(:delivery_receipt_invalid, token: usage) if lookup.status == :invalid
        return unless lookup.receipt
        return failure(:inactive_token, token: usage) unless usage.active?(decision_time)

        response = lookup.receipt.token_response_for(now: decision_time)
        result = success(
          token: usage,
          refresh_token: response.fetch(:refresh_token),
          previous_token: nil,
          token_response: response,
          access_expires_at: lookup.receipt.access_expires_at,
          refresh_expires_at: lookup.receipt.refresh_expires_at,
        )
      end
    end
    result
  end

  DeliveryLookup = Data.define(:status, :receipt)

  def delivery_lookup(usage, predecessor_digest, now: nil)
    return DeliveryLookup.new(status: :none, receipt: nil) unless usage.refresh_delivery_receipt_present?
    return DeliveryLookup.new(status: :invalid, receipt: nil) unless
      usage.refresh_delivery_ciphertext.present? && usage.refresh_delivery_predecessor_digest.present? &&
        usage.refresh_delivery_expires_at.present?

    receipt = OidcRefreshDeliveryReceipt.decrypt(usage.refresh_delivery_ciphertext)
    valid_binding = receipt.matches?(
      rp_session_public_id: usage.public_id,
      client_id: client_id,
      resource_type: resource_type,
      predecessor_digest: usage.refresh_delivery_predecessor_digest,
      generation: usage.refresh_generation,
    )
    return DeliveryLookup.new(status: :invalid, receipt: nil) unless valid_binding
    unless secure_equal?(receipt.expires_at, usage.refresh_delivery_expires_at)
      return DeliveryLookup.new(status: :invalid, receipt: nil)
    end

    now ||= usage.class.database_now
    return DeliveryLookup.new(status: :expired, receipt: nil) unless receipt.active_at?(now)
    return DeliveryLookup.new(status: :none, receipt: nil) unless
      secure_string_equal?(predecessor_digest, receipt.predecessor_digest)

    DeliveryLookup.new(status: :ready, receipt: receipt)
  rescue OidcRefreshDeliveryReceipt::Invalid, ArgumentError, KeyError, TypeError
    DeliveryLookup.new(status: :invalid, receipt: nil)
  end

  def reload_usage(usage)
    connection_owner_for(usage.class).connected_to(role: :writing) do
      usage.class.uncached { usage.reload }
    end
  end

  def publish_delivery!(store, usage, result)
    store.publish(
      resource_type: resource_type,
      rp_session_public_id: usage.public_id,
      ciphertext: usage.refresh_delivery_ciphertext,
    )
    result
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::SerializationError, Umaxica::Valkey::OperationError
    failure(:delivery_publication_failed, token: usage)
  end

  def release_delivery_lease(store, usage, owner)
    store.release(resource_type:, rp_session_public_id: usage.public_id, owner:)
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::SerializationError, Umaxica::Valkey::OperationError => e
    Rails.logger.warn("[OidcRefreshTokenIssuer] refresh lease release failed: #{e.class}")
  end

  def coordination_store
    @coordination_store ||= Valkey::AuthState::OidcRpRefreshCoordinationStore.new
  end

  def encoded_refresh_token_digest(usage, verifier)
    usage.digest_refresh_token(verifier).unpack1("H*")
  end

  def response_seconds(response, key)
    value = response[key] || response[key.to_s]
    seconds = value.is_a?(Integer) ? value : Integer(value.to_s, 10)
    raise ArgumentError, "RP token response #{key} is invalid" if seconds.negative?

    seconds
  rescue ArgumentError, TypeError
    raise ArgumentError, "RP token response #{key} is invalid"
  end

  def secure_equal?(left, right)
    left = left.to_time.utc.iso8601(6)
    right = right.to_time.utc.iso8601(6)
    ActiveSupport::SecurityUtils.secure_compare(left, right)
  rescue NoMethodError, TypeError
    false
  end

  def secure_string_equal?(left, right)
    left = left.to_s
    right = right.to_s
    return false unless left.bytesize == right.bytesize

    ActiveSupport::SecurityUtils.secure_compare(left, right)
  end

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

    context.connected_to(role: :writing) do
      usage_class.uncached { usage_class.find_by(public_id: public_id) }
    end
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

  def touch_oidc_connection!(usage, now: nil)
    connection = connection_for(usage)
    return unless connection

    connection.update!(last_used_at: now || usage.class.database_now)
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

  def success(token:, refresh_token:, previous_token:, token_response: nil, access_expires_at: nil,
              refresh_expires_at: nil)
    Result.new(
      success: true,
      token: token,
      refresh_token: refresh_token,
      previous_token: previous_token,
      reason: nil,
      token_response: token_response,
      access_expires_at: access_expires_at,
      refresh_expires_at: refresh_expires_at,
    )
  end

  def failure(reason, token: nil)
    Result.new(
      success: false,
      token: token,
      refresh_token: nil,
      previous_token: nil,
      reason: reason,
      token_response: nil,
      access_expires_at: nil,
      refresh_expires_at: nil,
    )
  end
end
