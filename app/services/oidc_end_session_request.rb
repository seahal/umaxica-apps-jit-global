# typed: false
# frozen_string_literal: true

class OidcEndSessionRequest < ApplicationService
  Result =
    Data.define(
      :success, :requires_confirmation, :error_code, :error_description, :source,
      :client, :client_id, :subject, :sid, :post_logout_redirect_uri, :state, :ui_locales,
      :legacy_ri,
    ) do
      def success? = success

      def requires_confirmation? = requires_confirmation

      def error? = error_code.present?
    end

  SOURCE_ID_TOKEN_HINT = :id_token_hint
  SOURCE_LOGOUT_REQUEST = :logout_request
  SOURCE_NO_HINT = :no_hint

  def initialize(params:, request:)
    super()
    @params = params
    @request = request
  end

  def call
    return handle_id_token_hint if param_present?(:id_token_hint)
    return handle_logout_request if param_present?(:logout_request)

    success(source: SOURCE_NO_HINT, requires_confirmation: true)
  end

  private

  attr_reader :params, :request

  def handle_id_token_hint
    verification = verified_id_token_hint
    return invalid_request("id_token_hint is invalid") unless verification

    payload = verification.fetch(:payload)
    client = verification.fetch(:client)
    return invalid_request("client_id mismatch") if param_present?(:client_id) && param(:client_id) != client.client_id

    redirect_uri = param(:post_logout_redirect_uri).presence
    if redirect_uri.present? && !OidcClientRegistry.valid_post_logout_redirect_uri?(
      client_id: client.client_id,
      uri: redirect_uri,
      resource_type: resource_type_for_request,
    )
      return invalid_request("post_logout_redirect_uri is invalid")
    end

    current_failure = current_session_mismatch(payload)
    return current_failure if current_failure

    # The hint names the RP session the RP wants ended; it is not authority for this browser to end
    # it. Its sub/sid become the logout target only after matching the verified current session.
    # Without one, the hint still validates client and redirect, but nothing is revoked or notified.
    target_bound = !current_session_missing?
    success(
      source: SOURCE_ID_TOKEN_HINT,
      client: client,
      client_id: client.client_id,
      subject: target_bound ? payload["sub"] : nil,
      sid: target_bound ? payload["sid"] : nil,
      post_logout_redirect_uri: redirect_uri,
      state: param(:state).presence,
      ui_locales: param(:ui_locales).presence,
      requires_confirmation: current_session_missing?,
    )
  end

  def handle_logout_request
    return success(source: SOURCE_LOGOUT_REQUEST, requires_confirmation: true) if request.get? || request.head?

    logout_request = OidcLogoutRequest.verify(param(:logout_request))
    return invalid_request("logout_request is invalid") unless logout_request

    client = OidcClientRegistry.find(logout_request[:client_id])
    return invalid_request("unknown client") unless client
    return invalid_request("client_id mismatch") if param_present?(:client_id) && param(:client_id) != client.client_id

    success(
      source: SOURCE_LOGOUT_REQUEST,
      client: client,
      client_id: client.client_id,
      legacy_ri: logout_request[:ri],
    )
  end

  def verified_id_token_hint
    resource_type = resource_type_for_request
    issuer = OidcIssuer.for_resource_type(resource_type)
    jwt_issuer_id = OidcIssuer.jwt_issuer_id_for_resource_type(resource_type)

    OidcClientRegistry.client_ids.lazy.filter_map do |client_id|
      client = OidcClientRegistry.find(client_id)
      next unless client

      payload = SecurityJwtOidcIdTokenCodec.decode(
        id_token: param(:id_token_hint),
        client_id: client.client_id,
        resource_type: resource_type,
        jwt_issuer_id: jwt_issuer_id,
        issuer: issuer,
      )
      { client: client, payload: payload }
    rescue JWT::DecodeError, JWT::VerificationError, OpenSSL::PKey::PKeyError, ArgumentError, TypeError
      nil
    end.first
  end

  def current_session_mismatch(payload)
    return if current_session_missing?

    expected_subject = current_subject
    if expected_subject.present? && payload["sub"].to_s != expected_subject
      return invalid_request("id_token_hint subject does not match current session")
    end

    expected_sid = current_sid
    return if expected_sid.blank? || payload["sid"].blank? || payload["sid"].to_s == expected_sid

    invalid_request("id_token_hint sid does not match current session")
  end

  def current_session_missing?
    current_actor.blank? || current_actor.is_a?(Unauthenticated)
  end

  def current_subject
    actor = current_actor
    return if actor.blank?

    OidcSubject.for(actor, resource_type: resource_type_for_request)
  rescue ArgumentError
    nil
  end

  def current_actor
    return if Actor.actor_type.to_sym == :unauthenticated

    actor = Actor.actor
    return if actor.respond_to?(:unauthenticated?) && actor.unauthenticated?

    actor
  end

  def current_sid
    Actor.authn.access_claims&.dig("sid").presence
  end

  def resource_type_for_request
    host = request.host.to_s

    return "operator" if host_matches?(host, OidcIssuer.host_for_resource_type("operator"))
    return "visitor" if host_matches?(host, OidcIssuer.host_for_resource_type("visitor"))

    "client"
  end

  def host_matches?(request_host, configured_host)
    configured = URI.parse("//#{configured_host}").host.to_s
    request_host == configured
  rescue URI::InvalidURIError
    request_host == configured_host.to_s
  end

  def success(**attributes)
    Result.new(
      success: true,
      requires_confirmation: false,
      error_code: nil,
      error_description: nil,
      source: nil,
      client: nil,
      client_id: nil,
      subject: nil,
      sid: nil,
      post_logout_redirect_uri: nil,
      state: nil,
      ui_locales: nil,
      legacy_ri: nil,
      **attributes,
    )
  end

  def invalid_request(description)
    Result.new(
      success: false,
      requires_confirmation: false,
      error_code: "invalid_request",
      error_description: description,
      source: nil,
      client: nil,
      client_id: nil,
      subject: nil,
      sid: nil,
      post_logout_redirect_uri: nil,
      state: nil,
      ui_locales: nil,
      legacy_ri: nil,
    )
  end

  def param_present?(key)
    param(key).present?
  end

  def param(key)
    params[key].to_s
  end
end
