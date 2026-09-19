# typed: false
# frozen_string_literal: true

require "faraday"

class OidcBackchannelLogoutDeliveryJob < ApplicationJob
  queue_as :default

  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 3

  class DeliveryResponseError < StandardError
    attr_reader :status

    def initialize(status)
      @status = status
      super("OIDC back-channel logout returned HTTP #{status}")
    end
  end

  class RetryableResponseError < DeliveryResponseError; end

  class PermanentResponseError < DeliveryResponseError; end

  retry_on RetryableResponseError, wait: :polynomially_longer, attempts: 5
  retry_on Faraday::Error, wait: :polynomially_longer, attempts: 5
  retry_on IOError, wait: :polynomially_longer, attempts: 5

  def perform(encrypted_payload, *legacy_payload)
    payload = delivery_payload(encrypted_payload, legacy_payload)
    client_id = payload.fetch(:client_id)
    return log_suspended(client_id) if suspended?(client_id)

    parsed_uri = registered_uri!(payload)
    logout_token = OidcLogoutTokenCodec.encode(
      client_id: client_id,
      resource_type: payload.fetch(:resource_type),
      subject: payload.fetch(:subject),
      sid: payload.fetch(:sid),
    )
    response = post_logout_token(parsed_uri, logout_token)
    validate_response!(response)
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.backchannel_logout.delivered",
        client_id: client_id,
        host: parsed_uri.host,
        status: response.status,
      ),
    )
  rescue DeliveryResponseError => e
    log_delivery_failure(
      client_id: defined?(client_id) ? client_id : nil,
      host: defined?(parsed_uri) ? parsed_uri&.host : nil,
      status: e.status,
      error_class: e.class.name,
    )
    raise
  rescue URI::InvalidURIError, IOError, *OutboundHttp::Connection::NETWORK_ERRORS => e
    log_delivery_failure(
      client_id: defined?(client_id) ? client_id : nil,
      host: defined?(parsed_uri) ? parsed_uri&.host : nil,
      error_class: e.class.name,
    )
    raise
  end

  private

  # Five-argument jobs may remain in a deployed queue during rollout. New
  # producers only enqueue the versioned encrypted envelope.
  def delivery_payload(encrypted_payload, legacy_payload)
    return OutboundSensitivePayload.decrypt_oidc_backchannel_logout(encrypted_payload) if legacy_payload.empty?

    raise ArgumentError, "Invalid legacy OIDC back-channel logout payload" unless legacy_payload.size == 4

    uri, client_id, resource_type, subject, sid = [encrypted_payload, *legacy_payload]
    { uri:, client_id:, resource_type:, subject:, sid: }
  end

  def registered_uri!(payload)
    client_id = payload.fetch(:client_id)
    resource_type = payload.fetch(:resource_type)
    uri = payload.fetch(:uri)
    registered = OidcClientRegistry.backchannel_logout_uris_for(client_id:, resource_type:)
    raise ArgumentError, "OIDC back-channel logout destination is no longer registered" unless registered.include?(uri)

    URI.parse(uri)
  end

  def suspended?(client_id)
    FeatureFlags.enabled?(
      :oidc_backchannel_logout_suspended,
      OidcClientFlipperActor.new(client_id: client_id.to_s),
    )
  end

  def log_suspended(client_id)
    Rails.logger.warn(
      JitLogEvent.format("oidc.backchannel_logout.suspended", client_id: client_id),
    )
    nil
  end

  # No connection-level retry and no redirect following. ActiveJob already
  # retries this delivery, and the destination is an allowlisted relying-party
  # URI: following a redirect off that list would reintroduce the SSRF the
  # registry check in registered_uri! exists to prevent.
  #
  # Local development registrations may use HTTP, but production must enforce
  # HTTPS even if a registration is accidentally misconfigured.
  def post_logout_token(uri, logout_token)
    connection = OutboundHttp::Connection.build(
      url: uri,
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT,
      require_https: Rails.env.production?,
    )
    connection.post(uri, "logout_token" => logout_token)
  end

  def validate_response!(response)
    status = Integer(response.status)
    return if status.between?(200, 299)

    error_class = retryable_status?(status) ? RetryableResponseError : PermanentResponseError
    raise error_class, status
  end

  def retryable_status?(status)
    [408, 425, 429].include?(status) || status.between?(500, 599)
  end

  def log_delivery_failure(client_id:, host:, status: nil, error_class:)
    Rails.logger.warn(
      JitLogEvent.format(
        "oidc.backchannel_logout.delivery_failed",
        client_id: client_id,
        host: host,
        status: status,
        error_class: error_class,
      ),
    )
  end
end
