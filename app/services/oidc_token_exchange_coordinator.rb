# typed: false
# frozen_string_literal: true

class OidcTokenExchangeCoordinator < ApplicationService
  class TokenIssuanceError < StandardError; end

  class ReplayRevocationError < StandardError; end

  class RpSessionAlreadyExists < StandardError; end

  class AuthorizationCodeReplayed < StandardError; end

  class AuthorizationGrantAlreadyRedeemed < StandardError; end

  Result =
    Data.define(:success, :token_response, :error, :error_description, :access_expires_at, :refresh_expires_at) do
      def success? = success
    end

  ConsumedCode =
    Data.define(
      :raw_code, :client_id, :redirect_uri, :subject, :base_session_ref, :code_challenge,
      :code_challenge_method, :nonce, :scope, :auth_time, :resource_type, :rp_session_ref,
      :refresh_family_ref, :authorization_transaction_ref, :acr, :amr, :issued_at, :expires_at, :state,
    ) do
      def auth_method = amr
    end

  def initialize(grant_type:, code: nil, refresh_token: nil, redirect_uri: nil, client_id:, client_secret: nil,
                 code_verifier: nil,
                 client_assertion_type: nil, client_assertion: nil,
                 dpop_proof: nil, token_endpoint_uri: nil, request_method: "POST",
                 expected_resource_type:,
                 code_store: Valkey::AuthState::AuthorizationCodeStore.new)
    super()
    @grant_type = grant_type
    @code = code
    @refresh_token = refresh_token
    @redirect_uri = redirect_uri
    @client_id = client_id
    @client_secret = client_secret
    @client_assertion_type = client_assertion_type
    @client_assertion = client_assertion
    @code_verifier = code_verifier
    @dpop_proof = dpop_proof
    @token_endpoint_uri = token_endpoint_uri
    @request_method = request_method
    @expected_resource_type = expected_resource_type
    @code_store = code_store
  end

  def call
    return failure(
      "invalid_request", "grant_type must be 'authorization_code' or 'refresh_token'",
    ) unless valid_grant_type?
    return failure("invalid_request", "token endpoint realm is required") unless expected_realm_configured?
    return failure("invalid_client", "OIDC client authentication failed") unless authenticated_client?

    if grant_type == "refresh_token"
      exchange_refresh_token!
    else
      exchange_authorization_code!
    end
  rescue OidcConnectionRecorder::StaleAuthorization
    failure("invalid_grant", "authorization code predates OIDC connection revocation")
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::SerializationError, Umaxica::Valkey::OperationError => e
    Rails.logger.error("[OidcTokenExchangeCoordinator] auth-state store failure: #{e.class}: #{e.message}")
    failure("server_error", "authorization code store unavailable")
  rescue TokenIssuanceError => e
    Rails.logger.error("[OidcTokenExchangeCoordinator] token issuance failed: #{e.class}")
    failure("server_error", "token issuance failed")
  rescue RpSession::IssuanceRejected
    failure("invalid_grant", "RP Session is no longer active")
  rescue ReplayRevocationError => e
    Rails.logger.error("[OidcTokenExchangeCoordinator] replay revocation failed: #{e.class}")
    failure("server_error", "authorization code replay revocation failed")
  rescue AuthorizationCodeReplayed
    failure("invalid_grant", "Authorization code already consumed")
  end

  private

  attr_reader :grant_type, :code, :refresh_token, :redirect_uri, :client_id, :client_secret, :client_assertion_type,
              :client_assertion, :code_verifier,
              :dpop_proof, :token_endpoint_uri, :request_method, :expected_resource_type, :code_store

  def valid_grant_type?
    %w(authorization_code refresh_token).include?(grant_type)
  end

  def authenticated_client?
    client = OidcClientRegistry.find(client_id)
    return false unless client

    return false if client_id.blank?

    case client.registered_token_endpoint_auth_method
    when "none"
      public_client_authenticated?
    when "private_key_jwt"
      return false if client_secret.present?

      authenticated_client_assertion?
    else
      return false if client_assertion.present? || client_assertion_type.present?

      OidcClientRegistry.authenticate(client_id, client_secret)
    end
  end

  def public_client_authenticated?
    client_secret.blank? && client_assertion.blank? && client_assertion_type.blank?
  end

  def authenticated_client_assertion?
    return false unless client_assertion_type == OidcClientAssertionJwt::ASSERTION_TYPE
    return false if token_endpoint_uri.blank?
    return false if client_assertion.blank?

    OidcClientRegistry.authenticate_assertion(
      client_id,
      client_assertion,
      token_url: token_endpoint_uri,
    )
  end

  def exchange_authorization_code!
    return failure("invalid_grant", "Authorization code not found") if code.blank?

    peeked = code_store.read(code)
    return failure("invalid_grant", "Authorization code not found") if peeked.blank?

    return failure("invalid_grant", "authorization code realm mismatch") unless
      expected_realm_matches?(peeked["resource_type"])

    precheck = prevalidate_payload(peeked)
    return precheck if precheck

    bound_session_failure = prevalidate_bound_session(peeked)
    return bound_session_failure if bound_session_failure

    dpop_jkt = validate_dpop_proof(resource_type: peeked["resource_type"])
    return dpop_jkt if dpop_jkt.is_a?(Result)

    if peeked["authorization_transaction_ref"].present?
      return issue_tokens_for_authorization_transaction!(peeked, dpop_jkt: dpop_jkt)
    end

    consume_result = code_store.consume!(
      raw_code: code,
      expected: {
        client_id: client_id,
        redirect_uri: redirect_uri,
        subject: peeked["subject"],
        base_session_ref: peeked["base_session_ref"],
        code_challenge: peeked["code_challenge"],
        code_challenge_method: peeked["code_challenge_method"],
        resource_type: expected_resource_type,
      },
    )

    case consume_result.status
    when :missing
      failure("invalid_grant", "Authorization code not found")
    when :expired
      failure("invalid_grant", "Authorization code expired")
    when :replay
      revoke_linked_family!(consume_result.payload)
      failure("invalid_grant", "Authorization code already consumed")
    when :mismatch
      failure("invalid_grant", "Authorization code mismatch")
    when :consumed
      issue_tokens_for_consumed!(consume_result.payload, dpop_jkt: dpop_jkt)
    else
      failure("server_error", "authorization code consume failed")
    end
  rescue RpSessionAlreadyExists
    failure("invalid_grant", "RP Session already exists for this Browser Session and client")
  end

  def exchange_refresh_token!
    return failure("invalid_grant", "refresh_token is required") if refresh_token.blank?

    resolved = resolve_refresh_usage
    return failure("invalid_grant", "refresh token not found") unless resolved

    usage = resolved.usage
    return failure("invalid_grant", "refresh token is not bound to this client") unless
      usage.oidc_client_id == client_id

    resource_type = resource_type_for_usage(usage)
    return failure("invalid_grant", "refresh token realm mismatch") unless
      expected_realm_matches?(resource_type)

    client = OidcClientRegistry.find(client_id)
    return failure("invalid_client", "unknown OIDC client") unless client
    return failure("invalid_grant", "refresh token resource mismatch") unless
      OidcIssuer.resource_type_for_client(client) == resource_type

    root_token = usage.parent_token
    resource = resource_for_root_token(root_token, resource_type)
    return failure("invalid_grant", "refresh token session is not active") unless
      root_token&.currently_usable? && resource&.active?

    auth_time = parse_time(usage.oidc_auth_time)
    return failure("invalid_grant", "refresh token authentication time missing") unless auth_time

    scopes = usage.oidc_scope.to_s.split
    return failure("invalid_grant", "refresh token scope is invalid") unless valid_refresh_scopes?(client, scopes)

    dpop_jkt = validate_refresh_dpop_proof(usage, resource_type)
    return dpop_jkt if dpop_jkt.is_a?(Result)

    rotation = rotate_refresh_token(
      resource: resource,
      client: client,
      auth_time: auth_time,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
    )
    return refresh_rotation_failure(rotation) unless rotation.success?

    Result.new(
      success: true,
      token_response: rotation.token_response,
      error: nil,
      error_description: nil,
      access_expires_at: rotation.access_expires_at,
      refresh_expires_at: rotation.refresh_expires_at,
    )
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    Rails.logger.error("[OidcTokenExchangeCoordinator] refresh rotation failed: #{e.class}")
    failure("server_error", "refresh token rotation failed")
  end

  def resource_type_for_usage(usage)
    case usage
    when ClientRpSession then "client"
    when OperatorRpSession then "operator"
    when VisitorRpSession then "visitor"
    else nil
    end
  end

  def resolve_refresh_usage
    OidcRefreshTokenIssuer.resolve(
      refresh_token: refresh_token,
      resource_type: expected_resource_type,
    )
  end

  def rotate_refresh_token(resource:, client:, auth_time:, resource_type:, dpop_jkt:)
    OidcRefreshTokenIssuer.call(
      refresh_token: refresh_token,
      client_id: client_id,
      resource_type: resource_type,
      response_builder: lambda do |usage:, refresh_token:, now:, **_|
        locked_root_token = usage.parent_token
        locked_resource = resource_for_root_token(locked_root_token, resource_type)
        result = issue_refreshed_token_result(
          usage: usage,
          resource: locked_resource || resource,
          client: client,
          root_token: locked_root_token,
          refresh_plain: refresh_token,
          dpop_jkt: dpop_jkt,
          auth_time: auth_time,
          resource_type: resource_type,
          now: now,
        )
        raise TokenIssuanceError, "refreshed token response could not be built" unless result.success?

        result.token_response
      end,
    )
  end

  def refresh_rotation_failure(rotation)
    case rotation.reason
    when :delivery_publication_failed, :coordination_timeout, :delivery_receipt_invalid
      failure("server_error", "refresh delivery unavailable")
    when :coordination_unavailable
      failure("server_error", "refresh coordination unavailable")
    when :refresh_token_reuse_detected
      failure("invalid_grant", "refresh token reuse detected")
    when :client_mismatch, :inactive_token, :invalid_digest
      failure("invalid_grant", "refresh token could not be rotated")
    else
      failure("server_error", "refresh token rotation failed")
    end
  end

  def resource_for_root_token(root_token, resource_type)
    return unless root_token

    case resource_type
    when "operator" then root_token.staff
    when "visitor" then root_token.visitor
    when "client" then root_token.user
    end
  end

  def valid_refresh_scopes?(client, scopes)
    scopes.include?("openid") && (scopes - client.allowed_scopes).empty?
  end

  def validate_refresh_dpop_proof(usage, resource_type)
    expected_jkt = usage.dpop_jkt.to_s
    return nil if expected_jkt.blank? && dpop_proof.blank?
    return failure("invalid_request", "DPoP proof is required") if expected_jkt.present? && dpop_proof.blank?
    return failure("invalid_request", "DPoP proof is not bound to the refresh token") if expected_jkt.blank?

    result = DpopProofVerifier.new(
      proof_jwt: dpop_proof,
      request_method: request_method,
      request_uri: token_endpoint_uri.to_s,
      resource_type: resource_type,
    ).call
    return failure("invalid_request", "DPoP proof invalid: #{result.error}") unless result.valid?
    return failure("invalid_request", "DPoP proof key mismatch") unless result.jkt == expected_jkt

    result.jkt
  end

  def prevalidate_payload(payload)
    return failure("invalid_grant", "Authorization code expired") if payload_expired?(payload)

    return failure("invalid_request", "redirect_uri mismatch") unless payload["redirect_uri"] == redirect_uri
    return failure("invalid_request", "client_id mismatch") unless payload["client_id"] == client_id
    return failure(
      "invalid_request",
      "redirect_uri is not registered for this authorization code's realm",
    ) unless OidcClientRegistry.valid_redirect_uri?(
      client_id, payload["redirect_uri"], resource_type: payload["resource_type"],
    )

    pkce_failure = verify_pkce(payload)
    return pkce_failure if pkce_failure

    scope_failure = validate_authorized_scopes(payload)
    return scope_failure if scope_failure

    if payload["state"] != "issued"
      revoke_linked_family!(payload)
      return failure("invalid_grant", "Authorization code already consumed")
    end

    return failure("invalid_grant", "authorization code predates OIDC connection revocation") if
      oidc_connection_revoked_after_code?(payload)

    if parse_time(payload["auth_time"]).blank?
      return failure("invalid_grant", "Authorization code authentication time missing")
    end

    nil
  end

  # The authorization code is an opaque capability, but it is not sufficient by
  # itself to authorize issuance. Validate the exact Base Browser Session and
  # its actor before the destructive Valkey CAS so an already stale session does
  # not burn a code that could never produce credentials.
  def prevalidate_bound_session(payload)
    authorization_code = wrap_payload(payload)
    resource = resolve_resource(authorization_code)
    return failure("invalid_grant", "resource is not active") unless resource&.active?

    root_token = resolve_root_token(authorization_code)
    return failure("invalid_grant", "Authorization code is unbound") if root_token.blank?
    return failure("invalid_grant", "root session is not active") unless root_browser_session_usable?(root_token)
    return failure("invalid_grant", "root session actor mismatch") unless root_token_actor_matches?(
      root_token,
      resource,
    )

    nil
  end

  def payload_expired?(payload)
    expires_at = payload["expires_at"]
    return false if expires_at.blank?

    Time.iso8601(expires_at) <= Time.current
  rescue ArgumentError
    true
  end

  def validate_authorized_scopes(payload)
    client = OidcClientRegistry.find!(client_id)
    requested_scopes = payload["scope"].to_s.split
    invalid_scopes = requested_scopes - client.allowed_scopes

    return nil if requested_scopes.include?("openid") && invalid_scopes.empty?

    failure("invalid_grant", "Authorization code scope is invalid")
  end

  def oidc_connection_revoked_after_code?(payload)
    issued_at = parse_time(payload["issued_at"])
    return true if issued_at.blank?

    resource_type = payload["resource_type"].to_s
    resource = resolve_resource(wrap_payload(payload))
    return false unless resource

    connection_class = oidc_connection_class_for(resource_type)
    actor_key = connection_class.actor_foreign_key
    connection =
      connection_owner_for(connection_class).connected_to(role: :writing) do
        connection_class.find_by(actor_key => resource.id, :client_id => payload["client_id"])
      end
    connection&.revoked_at.present? && issued_at <= connection.revoked_at
  end

  def oidc_connection_class_for(resource_type)
    case resource_type.to_s
    when "operator" then OperatorOidcConnection
    when "visitor" then VisitorOidcConnection
    when "client" then ClientOidcConnection
    else
      raise ArgumentError, "unsupported OIDC resource type: #{resource_type.inspect}"
    end
  end

  def verify_pkce(payload)
    return failure("invalid_request", "code_verifier is required") if code_verifier.blank?
    return nil if OidcPkce.verify(
      code_verifier: code_verifier,
      code_challenge: payload["code_challenge"],
      code_challenge_method: payload["code_challenge_method"],
    )

    failure("invalid_request", "PKCE verification failed")
  end

  def issue_tokens_for_consumed!(payload, dpop_jkt:)
    authorization_code = wrap_payload(payload)
    resource = resolve_resource(authorization_code)

    root_token = resolve_root_token(authorization_code)
    return failure("invalid_grant", "Authorization code is unbound") if root_token.blank?

    client = OidcClientRegistry.find!(client_id)
    connection_class = connection_class_for(authorization_code.resource_type)

    connection_class.connected_to(role: :writing) do
      issuance_result = nil
      connection_class.transaction do
        # The code CAS is outside PostgreSQL. Re-lock and re-read the parent
        # after the CAS so a revoke racing with exchange wins before any RP
        # Session, refresh token, or access token authority is created.
        decision_time = connection_class.database_now

        with_current_root_token_lock(root_token, resource) do |locked_root_token, device_session|
          unless bound_session_usable_after_code_cas?(locked_root_token, resource, device_session: device_session)
            issuance_result = failure("invalid_grant", "root session is not active")
            next
          end

          usage = prepare_exchanged_usage(
            authorization_code: authorization_code,
            resource: resource,
            client: client,
            root_token: locked_root_token,
            dpop_jkt: dpop_jkt,
            now: decision_time,
          )

          refresh_plain = issue_or_rotate_usage_refresh_token!(usage, now: decision_time)
          link_consumed_family!(authorization_code, usage)
          issuance_result = issue_exchanged_token_result(
            authorization_code: authorization_code,
            resource: resource,
            client: client,
            root_token: locked_root_token,
            usage: usage,
            refresh_plain: refresh_plain,
            dpop_jkt: dpop_jkt,
            now: decision_time,
          )
        end
      end
      issuance_result
    end
  end

  # Authorization codes issued as aliases of a durable Base authorization
  # transaction use PostgreSQL as the one-time grant authority. Valkey remains
  # a short-lived transport and is consumed only after the RP Session and token
  # issuance transaction has committed.
  def issue_tokens_for_authorization_transaction!(payload, dpop_jkt:)
    authorization_code = wrap_payload(payload)
    resource = resolve_resource(authorization_code)
    return failure("invalid_grant", "resource is not active") unless resource&.active?

    root_token = resolve_root_token(authorization_code)
    return failure("invalid_grant", "Authorization code is unbound") if root_token.blank?

    client = OidcClientRegistry.find!(client_id)
    connection_class = connection_class_for(authorization_code.resource_type)
    transaction_class = authorization_transaction_class_for(authorization_code.resource_type)
    issuance_result, usage_for_link =
      connection_class.connected_to(role: :writing) do
      connection_class.transaction do
        issue_authorization_transaction_database!(
          authorization_code: authorization_code,
          resource: resource,
          client: client,
          root_token: root_token,
          transaction_class: transaction_class,
          dpop_jkt: dpop_jkt,
        )
      end
    end

    finalize_authorization_code_transport!(payload, usage_for_link) if issuance_result&.success?

    issuance_result || failure("server_error", "authorization grant exchange failed")
  rescue RpSessionAlreadyExists
    failure("invalid_grant", "RP Session already exists for this Browser Session and client")
  end

  def issue_authorization_transaction_database!(authorization_code:, resource:, client:, root_token:,
                                                transaction_class:, dpop_jkt:)
    authorization_transaction = transaction_class.lock.find_by(
      transaction_id: authorization_code.authorization_transaction_ref,
    )
    decision_time = transaction_class.database_now
    unless authorization_grant_matches?(authorization_transaction, authorization_code, now: decision_time)
      return [failure("invalid_grant", "authorization transaction mismatch"), nil]
    end
    unless authorization_transaction.claim_authorization_grant_locked!(now: decision_time)
      return [failure("invalid_grant", "authorization grant already redeemed"), nil]
    end

    with_current_root_token_lock(root_token, resource) do |locked_root_token, device_session|
      unless bound_session_usable_after_code_cas?(locked_root_token, resource, device_session: device_session)
        return [failure("invalid_grant", "root session is not active"), nil]
      end

      usage = prepare_exchanged_usage(
        authorization_code: authorization_code,
        resource: resource,
        client: client,
        root_token: locked_root_token,
        dpop_jkt: dpop_jkt,
        now: decision_time,
      )
      refresh_plain = issue_or_rotate_usage_refresh_token!(usage, now: decision_time)
      result = issue_exchanged_token_result(
        authorization_code: authorization_code,
        resource: resource,
        client: client,
        root_token: locked_root_token,
        usage: usage,
        refresh_plain: refresh_plain,
        dpop_jkt: dpop_jkt,
        now: decision_time,
      )
      [result, usage]
    end
  end

  def prepare_exchanged_usage(authorization_code:, resource:, client:, root_token:, dpop_jkt:, now:)
    OidcConnectionRecorder.call(
      resource: resource,
      client: client,
      scope: authorization_code.scope,
      authorization_issued_at: authorization_code.issued_at,
      used_at: now,
    )

    create_or_resolve_active_usage!(
      root_token: root_token,
      client: client,
      scope: authorization_code.scope,
      dpop_jkt: dpop_jkt,
      auth_time: authorization_code.auth_time,
      acr: authorization_code.acr,
      amr: authorization_code.amr,
      nonce: authorization_code.nonce,
      now: now,
    )
  end

  def bound_session_usable_after_code_cas?(root_token, resource, device_session: nil)
    return false unless root_token&.currently_usable?
    return false unless resource

    device_session ||= device_session_for_root_token(root_token)
    return false unless device_session&.usable?
    return false unless device_session.current_refresh_token_id == root_token.id

    resource.reload
    resource.active? && root_token_actor_matches?(root_token, resource)
  rescue ActiveRecord::RecordNotFound
    false
  end

  def root_browser_session_usable?(root_token)
    device_session = device_session_for_root_token(root_token)
    device_session&.usable? &&
      device_session.current_refresh_token_id == root_token.id &&
      root_token.currently_usable?
  end

  def wrap_payload(payload)
    ConsumedCode.new(
      raw_code: code,
      client_id: payload["client_id"],
      redirect_uri: payload["redirect_uri"],
      subject: payload["subject"],
      base_session_ref: payload["base_session_ref"],
      code_challenge: payload["code_challenge"],
      code_challenge_method: payload["code_challenge_method"],
      nonce: payload["nonce"],
      scope: payload["scope"],
      auth_time: parse_time(payload["auth_time"]),
      resource_type: payload["resource_type"],
      rp_session_ref: payload["rp_session_ref"],
      refresh_family_ref: payload["refresh_family_ref"],
      authorization_transaction_ref: payload["authorization_transaction_ref"],
      acr: payload["acr"],
      amr: payload["amr"],
      issued_at: parse_time(payload["issued_at"]),
      expires_at: parse_time(payload["expires_at"]),
      state: payload["state"],
    )
  end

  def authorization_transaction_class_for(resource_type)
    case resource_type.to_s
    when "client" then ClientOidcAuthorizationTransaction
    when "visitor" then VisitorOidcAuthorizationTransaction
    when "operator" then OperatorOidcAuthorizationTransaction
    else
      raise ArgumentError, "unsupported OIDC authorization resource type: #{resource_type.inspect}"
    end
  end

  def authorization_grant_matches?(transaction, authorization_code, now:)
    return false unless transaction
    return false if transaction.expired?(now: now)
    return false unless transaction.surface == surface_for_resource_type(authorization_code.resource_type)
    return false unless transaction.client_id == authorization_code.client_id
    return false unless transaction.redirect_uri == authorization_code.redirect_uri
    return false unless transaction.code_challenge == authorization_code.code_challenge
    return false unless transaction.code_challenge_method == authorization_code.code_challenge_method
    return false unless transaction.nonce == authorization_code.nonce
    return false unless transaction.scope == authorization_code.scope
    return false if transaction.base_finalized_at.blank?
    return false unless transaction.status == OidcAuthorizationTransactionable::STATUS_CONSUMED
    return false unless transaction.browser_session_ref == authorization_code.base_session_ref
    return false unless transaction.actor_ref == OidcSubject.public_id_from(
      authorization_code.subject,
      resource_type: authorization_code.resource_type,
    )

    true
  end

  def surface_for_resource_type(resource_type)
    case resource_type.to_s
    when "client" then "app"
    when "visitor" then "com"
    when "operator" then "org"
    else nil
    end
  end

  def finalize_authorization_code_transport!(payload, usage)
    consume_result = code_store.consume!(
      raw_code: code,
      expected: {
        client_id: payload["client_id"],
        redirect_uri: payload["redirect_uri"],
        subject: payload["subject"],
        base_session_ref: payload["base_session_ref"],
        code_challenge: payload["code_challenge"],
        code_challenge_method: payload["code_challenge_method"],
        resource_type: expected_resource_type,
      },
    )
    return unless consume_result.success?

    link_consumed_family!(wrap_payload(consume_result.payload), usage)
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::SerializationError,
         Umaxica::Valkey::OperationError, AuthorizationCodeReplayed => e
    Rails.logger.error(
      "[OidcTokenExchangeCoordinator] authorization code transport cleanup failed: #{e.class}",
    )
  end

  def parse_time(value)
    return nil if value.blank?
    return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

    Time.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def resolve_resource(authorization_code)
    public_id = OidcSubject.public_id_from(
      authorization_code.subject,
      resource_type: authorization_code.resource_type,
    )
    return nil if public_id.blank?

    case authorization_code.resource_type
    when "operator" then Operator.find_by(public_id: public_id)
    when "visitor" then Visitor.find_by(public_id: public_id)
    when "client" then Client.find_by(public_id: public_id)
    else nil
    end
  end

  def resolve_root_token(authorization_code)
    ref = authorization_code.base_session_ref
    return nil if ref.blank?

    case authorization_code.resource_type
    when "operator" then OperatorToken.find_by(public_id: ref)
    when "visitor" then VisitorToken.find_by(public_id: ref)
    when "client" then ClientToken.find_by(public_id: ref)
    else nil
    end
  end

  def link_consumed_family!(authorization_code, usage)
    family_ref =
      if usage.respond_to?(:refresh_token_family_id)
        usage.refresh_token_family_id
      end
    result = code_store.link_family!(
      raw_code: authorization_code.raw_code,
      rp_session_ref: usage.public_id,
      refresh_family_ref: family_ref,
    )
    return result if result&.status == :linked
    # A verified replay reached the tombstone between consume and link. Raising inside the
    # issuing transaction rolls back the RP Session and refresh rotation, so no credentials
    # are returned for a replayed code.
    raise AuthorizationCodeReplayed if result&.status == :replay_detected

    status = result&.status || "unknown"
    raise Umaxica::Valkey::OperationError, "authorization code family link failed: #{status}"
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError, Umaxica::Valkey::SerializationError => e
    Rails.logger.error("[OidcTokenExchangeCoordinator] failed to link RP family on tombstone: #{e.class}")
    raise
  end

  def revoke_linked_family!(payload)
    return if payload.blank?
    return unless replay_owner_matches?(payload)

    # Mark the replay atomically before reading the family link. If the winning exchange
    # has not linked yet, the mark makes its link fail; if it already linked, the marked
    # payload names the family to revoke.
    marked = code_store.mark_replay!(raw_code: code)
    payload = marked.payload if marked.status == :marked && marked.payload.present?

    rp_ref = payload["rp_session_ref"].presence
    return if rp_ref.blank?

    resource_type = payload["resource_type"].to_s
    session_class = rp_session_class_for(resource_type)
    return unless session_class

    connection_owner_for(session_class).connected_to(role: :writing) do
      if rp_ref.present?
        session = session_class.find_by(public_id: rp_ref)
        RpSessionRevoker.call(scope: :rp_session, record: session, status: "failed") if session
      end
    end
  rescue StandardError => e
    Rails.logger.error("[OidcTokenExchangeCoordinator] replay family revoke failed: #{e.class}")
    raise ReplayRevocationError, "authorization code replay revocation failed", cause: e
  end

  def replay_owner_matches?(payload)
    return false unless payload["client_id"] == client_id
    return false unless payload["redirect_uri"] == redirect_uri
    return false unless OidcClientRegistry.valid_redirect_uri?(
      client_id, payload["redirect_uri"], resource_type: payload["resource_type"],
    )

    verify_pkce(payload).nil?
  end

  def rp_session_class_for(resource_type)
    case resource_type
    when "operator" then OperatorRpSession
    when "visitor" then VisitorRpSession
    when "client" then ClientRpSession
    end
  end

  def create_or_resolve_active_usage!(root_token:, client:, scope:, dpop_jkt:, auth_time:, acr:, amr:, nonce:, now:)
    usage_class = usage_class_for_root_token(root_token)
    owner = connection_owner_for(usage_class)
    device_session = device_session_for_root_token(root_token)
    raise RpSession::IssuanceRejected, "Browser Session is missing" unless device_session&.usable?
    unless device_session.current_refresh_token_id == root_token.id && root_token.currently_usable?
      raise RpSession::IssuanceRejected, "Browser Session current root token is not active"
    end

    usage = nil

    owner.connected_to(role: :writing) do
      lookup = { oidc_client_id: client.client_id }
      lookup[:device_session_id] = device_session.id
      existing_usage = usage_class.lock.where(lookup).to_a
      if existing_usage.any? { |record| record.retirement_pending? }
        raise RpSessionAlreadyExists, "an RP Session for this Browser Session and client is not retired"
      end

      attributes = {
        oidc_client_id: client.client_id,
        oidc_scope: scope,
        oidc_jti: SecureRandom.uuid,
        dpop_jkt: dpop_jkt,
        oidc_auth_time: auth_time,
        oidc_acr: acr,
        oidc_amr: JSON.generate(Array(amr).map(&:to_s)),
        oidc_nonce: nonce,
        last_used_at: now,
        refresh_token_expires_at: refresh_expires_at_for(root_token, now: now),
        device_session_id: device_session.id,
      }
      if usage_class == ClientRpSession
        attributes[:client_token] = root_token
        attributes[:client_device_session] = device_session
      elsif usage_class == VisitorRpSession
        attributes[:visitor_token] = root_token
        attributes[:visitor_device_session] = device_session
      elsif usage_class == OperatorRpSession
        attributes[:operator_token] = root_token
        attributes[:operator_device_session] = device_session
      else
        raise ArgumentError, "unsupported RP Session class: #{usage_class.name}"
      end
      usage = usage_class.create!(**attributes)

      usage
    end
  rescue ActiveRecord::RecordNotUnique
    raise RpSessionAlreadyExists, "an RP Session for this Browser Session and client already exists"
  end

  def issue_or_rotate_usage_refresh_token!(usage, now:)
    if usage.refresh_token_digest.present?
      usage.rotate_refresh_token!(now: now)
    else
      usage.issue_refresh_token!(now: now)
    end
  end

  def rp_session_oidc_jti(usage)
    usage.oidc_jti.presence || raise(ArgumentError, "OIDC token usage is missing oidc_jti")
  end

  def issue_exchanged_token_result(authorization_code:, resource:, client:, root_token:, usage:, refresh_plain:,
                                   dpop_jkt:, now:)
    resource_type = authorization_code.resource_type
    client = client_for_resource_type(client, resource_type)
    issuer = OidcIssuer.for_resource_type(resource_type)
    subject = OidcSubject.for(resource, resource_type: resource_type)
    access_expires_at = session_token_expiry(now, root_token)
    auth_time = authorization_code.auth_time
    usage.record_access_token_expiry!(access_expires_at, now: now)
    access_token = encode_exchanged_access_token(
      authorization_code: authorization_code, resource: resource, client: client, root_token: root_token,
      usage: usage, dpop_jkt: dpop_jkt, access_expires_at: access_expires_at,
      resource_type: resource_type, issuer: issuer, subject: subject, auth_time: auth_time,
    )
    id_token = encode_exchanged_id_token(
      authorization_code: authorization_code, resource: resource, client: client, usage: usage,
      now: now, root_token: root_token, resource_type: resource_type, issuer: issuer, subject: subject,
      auth_time: auth_time,
    )
    raise TokenIssuanceError, "required token output is blank" if access_token.blank? || id_token.blank? ||
      refresh_plain.blank?

    Result.new(
      success: true,
      token_response: {
        access_token: access_token,
        token_type: dpop_jkt.present? ? "DPoP" : "Bearer",
        expires_in: [(access_expires_at - now).to_i, 0].max,
        refresh_token: refresh_plain,
        refresh_token_expires_in: [(usage.refresh_token_expires_at - now).to_i, 0].max,
        id_token: id_token,
      },
      error: nil,
      error_description: nil,
      access_expires_at: access_expires_at,
      refresh_expires_at: usage.refresh_token_expires_at,
    )
  end

  def issue_refreshed_token_result(usage:, resource:, client:, root_token:, refresh_plain:, dpop_jkt:,
                                   auth_time:, resource_type:, now:)
    client = client_for_resource_type(client, resource_type)
    issuer = OidcIssuer.for_resource_type(resource_type)
    subject = OidcSubject.for(resource, resource_type: resource_type)
    access_expires_at = session_token_expiry(now, root_token)
    scopes = usage.oidc_scope.to_s.split
    amr = parse_stored_amr(usage.oidc_amr)
    usage.record_access_token_expiry!(access_expires_at, now: now)
    access_token = refreshed_access_token(
      usage:, resource:, root_token:, dpop_jkt:, auth_time:, resource_type:, client:, issuer:, subject:,
      scopes:, amr:, access_expires_at:,
    )
    id_token =
      refreshed_id_token(
        usage:, resource:, root_token:, auth_time:, resource_type:, client:, issuer:, subject:, scopes:, amr:, now:,
      )
    raise TokenIssuanceError, "required token output is blank" if access_token.blank? || refresh_plain.blank? ||
      (scopes.include?("openid") && id_token.blank?)

    Result.new(
      success: true,
      token_response: {
        access_token: access_token,
        token_type: dpop_jkt.present? ? "DPoP" : "Bearer",
        expires_in: [(access_expires_at - now).to_i, 0].max,
        refresh_token: refresh_plain,
        refresh_token_expires_in: [(usage.refresh_token_expires_at - now).to_i, 0].max,
        id_token: id_token,
      }.compact,
      error: nil,
      error_description: nil,
      access_expires_at: access_expires_at,
      refresh_expires_at: usage.refresh_token_expires_at,
    )
  end

  def refreshed_access_token(usage:, resource:, root_token:, dpop_jkt:, auth_time:, resource_type:, client:, issuer:,
                             subject:, scopes:, amr:, access_expires_at:)
    AuthenticationTokenService.encode(
      resource,
      host: OidcIssuer.host_for_resource_type(resource_type),
      session_public_id: root_token.public_id,
      base_session_public_id: root_token.public_id,
      oidc_sid: usage.public_id,
      oidc_jti: rp_session_oidc_jti(usage),
      resource_type: resource_type,
      expires_at: access_expires_at,
      scopes: scopes,
      acr: usage.oidc_acr,
      amr: amr,
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
      issuer: issuer,
      audiences: [client.aud],
      subject: subject,
      auth_time: auth_time,
      client_id: client.client_id,
    )
  end

  def refreshed_id_token(
    usage:, resource:, root_token:, auth_time:, resource_type:, client:, issuer:, subject:, scopes:, amr:, now:
  )
    return unless scopes.include?("openid")

    OidcIdTokenIssuer.call(
      resource: resource,
      client: client,
      nonce: usage.oidc_nonce,
      issued_at: now,
      expires_at: SessionAbsoluteExpiryValue.cap(
        proposed_expiry: now + OidcIdTokenIssuer::TOKEN_TTL,
        absolute_expiry: root_token.discard_at,
      ),
      acr: usage.oidc_acr,
      amr: amr,
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
      issuer: issuer,
      subject: subject,
      sid: usage.public_id,
      auth_time: auth_time,
    )
  end

  def parse_stored_amr(value)
    return [] if value.blank?

    parsed = JSON.parse(value.to_s)
    parsed.is_a?(Array) ? parsed.map(&:to_s) : []
  rescue JSON::ParserError
    []
  end

  def encode_exchanged_access_token(authorization_code:, resource:, client:, root_token:, usage:, dpop_jkt:,
                                    access_expires_at:, resource_type:, issuer:, subject:, auth_time:)
    AuthenticationTokenService.encode(
      resource,
      host: OidcIssuer.host_for_resource_type(resource_type),
      session_public_id: root_token.public_id,
      base_session_public_id: root_token.public_id,
      oidc_sid: usage.public_id,
      oidc_jti: rp_session_oidc_jti(usage),
      resource_type: resource_type,
      expires_at: access_expires_at,
      scopes: authorization_code.scope.to_s.split,
      acr: authorization_code.acr,
      amr: Array(authorization_code.auth_method),
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
      issuer: issuer,
      audiences: [client.aud],
      subject: subject,
      auth_time: auth_time,
      client_id: client.client_id,
    )
  end

  def encode_exchanged_id_token(authorization_code:, resource:, client:, usage:, now:, root_token:, resource_type:,
                                issuer:, subject:, auth_time:)
    OidcIdTokenIssuer.call(
      resource: resource,
      client: client,
      nonce: authorization_code.nonce,
      issued_at: now,
      expires_at: SessionAbsoluteExpiryValue.cap(
        proposed_expiry: now + OidcIdTokenIssuer::TOKEN_TTL,
        absolute_expiry: root_token.discard_at,
      ),
      acr: authorization_code.acr,
      amr: Array(authorization_code.auth_method),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
      issuer: issuer,
      subject: subject,
      sid: usage.public_id,
      auth_time: auth_time,
    )
  end

  def usage_class_for_root_token(root_token)
    case root_token
    when ClientToken then ClientRpSession
    when OperatorToken then OperatorRpSession
    when VisitorToken then VisitorRpSession
    else
      raise ArgumentError, "unsupported root token class: #{root_token.class.name}"
    end
  end

  def connection_owner_for(klass)
    owner = klass
    owner = owner.superclass until owner.connection_class? || owner == ApplicationRecord
    owner
  end

  def with_current_root_token_lock(root_token, _resource)
    device_session = device_session_for_root_token(root_token)
    raise RpSession::IssuanceRejected, "Browser Session is missing" unless device_session

    device_session.with_lock do
      current_root_token = current_root_token_for(device_session)
      unless current_root_token && current_root_token.id == root_token.id
        raise RpSession::IssuanceRejected, "Browser Session current root token changed"
      end

      current_root_token.with_lock do
        yield current_root_token, device_session
      end
    end
  end

  def device_session_for_root_token(root_token)
    case root_token
    when ClientToken then ClientDeviceSession.find_by(id: root_token.device_session_id)
    when VisitorToken then VisitorDeviceSession.find_by(id: root_token.device_session_id)
    when OperatorToken then OperatorDeviceSession.find_by(id: root_token.device_session_id)
    else
      raise ArgumentError, "unsupported root token class: #{root_token.class.name}"
    end
  end

  def current_root_token_for(device_session)
    case device_session
    when ClientDeviceSession then ClientToken.find_by(id: device_session.current_refresh_token_id)
    when VisitorDeviceSession then VisitorToken.find_by(id: device_session.current_refresh_token_id)
    when OperatorDeviceSession then OperatorToken.find_by(id: device_session.current_refresh_token_id)
    else
      raise ArgumentError, "unsupported Device Session class: #{device_session.class.name}"
    end
  end

  def root_token_actor_matches?(root_token, resource)
    case root_token
    when ClientToken then root_token.user == resource
    when OperatorToken then root_token.staff == resource
    when VisitorToken then root_token.visitor == resource
    else false
    end
  end

  def refresh_expires_at_for(root_token, now:)
    ttl =
      case root_token
      when OperatorToken then SecurityTokenLifetimes::OPERATOR_REFRESH_TOKEN_TTL
      when VisitorToken then SecurityTokenLifetimes::VISITOR_REFRESH_TOKEN_TTL
      else SecurityTokenLifetimes::CLIENT_REFRESH_TOKEN_TTL
      end
    SessionAbsoluteExpiryValue.cap(
      proposed_expiry: now + ttl,
      absolute_expiry: root_token.discard_at,
    )
  end

  def session_token_expiry(now, root_token)
    SessionAbsoluteExpiryValue.cap(
      proposed_expiry: now + AuthenticationBase::ACCESS_TOKEN_TTL,
      absolute_expiry: root_token.discard_at,
    )
  end

  def connection_class_for(resource_type)
    case resource_type
    when "operator" then OrgTicketRecord
    when "visitor" then ComTicketRecord
    when "client" then AppTicketRecord
    else
      raise ArgumentError, "unsupported OIDC resource type: #{resource_type.inspect}"
    end
  end

  def validate_dpop_proof(resource_type:)
    return nil if dpop_proof.blank?

    result = DpopProofVerifier.new(
      proof_jwt: dpop_proof,
      request_method: request_method,
      request_uri: token_endpoint_uri.to_s,
      resource_type: resource_type,
    ).call

    return failure("invalid_request", "DPoP proof invalid: #{result.error}") unless result.valid?

    result.jkt
  end

  def client_for_resource_type(client, resource_type)
    OidcClientRegistry::VisitorAccount.new(
      client_id: client.client_id,
      client_secret: client.client_secret,
      redirect_uris: client.redirect_uris,
      redirect_uris_by_realm: client.redirect_uris_by_realm,
      post_logout_redirect_uris: client.post_logout_redirect_uris,
      backchannel_logout_uris: client.backchannel_logout_uris,
      backchannel_logout_session_required: client.backchannel_logout_session_required,
      aud: client.aud,
      resource_type: resource_type,
      name: client.name,
      domains: client.domains,
      allowed_scopes: client.allowed_scopes,
      registered_token_endpoint_auth_method: client.registered_token_endpoint_auth_method,
      metadata_token_endpoint_auth_method: client.metadata_token_endpoint_auth_method,
      jwt_namespace: client.jwt_namespace,
    )
  end

  def failure(error, description)
    Result.new(
      success: false,
      token_response: nil,
      error: error,
      error_description: description,
      access_expires_at: nil,
      refresh_expires_at: nil,
    )
  end

  def expected_realm_matches?(actual_resource_type)
    expected_realm_configured? &&
      actual_resource_type.to_s == expected_resource_type.to_s
  end

  def expected_realm_configured?
    %w(client operator visitor).include?(expected_resource_type.to_s)
  end
end
