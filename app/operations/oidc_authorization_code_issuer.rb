# typed: false
# frozen_string_literal: true

class OidcAuthorizationCodeIssuer < ApplicationService
  def initialize(client:, params:, resource:, session_token:, auth_method: nil, acr: nil,
                 authentication_event_at: nil, authorization_transaction_ref: nil,
                 store: Valkey::AuthState::AuthorizationCodeStore.new)
    super()
    @client = client
    @params = params
    @resource = resource
    @session_token = session_token
    @auth_method = auth_method
    @acr = acr
    @authentication_event_at = authentication_event_at
    @authorization_transaction_ref = authorization_transaction_ref
    @store = store
  end

  def call
    validate_session_token!
    raw_code = @store.issue!(
      client_id: params[:client_id],
      redirect_uri: params[:redirect_uri],
      subject: OidcSubject.for(resource, resource_type: resource_type),
      base_session_ref: session_token.public_id,
      code_challenge: params[:code_challenge],
      code_challenge_method: params[:code_challenge_method],
      nonce: params[:nonce],
      scope: params[:scope],
      auth_time: required_authentication_event_at,
      resource_type: resource_type,
      authorization_transaction_ref: authorization_transaction_ref,
      acr: acr,
      amr: auth_method,
      ttl: authorization_code_ttl,
    )

    OidcIssuedAuthorizationCode.new(
      code: raw_code,
      redirect_uri: params[:redirect_uri],
      state: params[:state],
      resource_type: resource_type,
      client_id: params[:client_id],
      nonce: params[:nonce],
      scope: params[:scope],
    )
  end

  private

  attr_reader :client, :params, :resource, :session_token, :auth_method, :acr, :authentication_event_at,
              :authorization_transaction_ref

  def required_authentication_event_at
    return authentication_event_at if authentication_event_at.present?

    raise ArgumentError, "authentication event time is required"
  end

  # An authorization code remains independently short-lived, but an OIDC code issued from an
  # admitted Sign-in path must not survive that path's fixed curfew. Direct RP-session issuance has
  # no Admission Binding and keeps the ordinary ten-second lifetime.
  def authorization_code_ttl
    default_ttl = Valkey::AuthState::AuthorizationCodeStore::CODE_TTL
    return default_ttl if authorization_transaction_ref.blank?

    surface = { "client" => "app", "visitor" => "com", "operator" => "org" }.fetch(resource_type)
    transaction_model = OidcAuthorizationTransactionCoordinator.model_for(surface)
    transaction = transaction_model.find_by(transaction_id: authorization_transaction_ref)
    return default_ttl unless transaction

    binding_model = BaseAuthAdmissionCoordinator.admission_binding_model(surface)
    binding_model.connection_owner.connected_to(role: :writing) do
      binding = binding_model.where(
        authorization_transaction_id: transaction.id, purpose: "authentication_handoff",
      ).where.not(redeemed_at: nil).order(redeemed_at: :desc, id: :desc).first
      return default_ttl unless binding

      now = binding_model.database_now
      remaining = binding.curfew_at - now
      raise ArgumentError, "sign-in path curfew has passed" unless remaining.positive?

      [default_ttl, remaining].min
    end
  end

  def validate_session_token!
    raise ArgumentError, "session_token is required" if session_token.blank?
    raise ArgumentError, "session token actor mismatch" unless session_token_actor_matches?
    raise ArgumentError,
          "session token is inactive" unless session_token.respond_to?(:active_status?) &&
            session_token.active_status?
    raise ArgumentError, "session token public_id is required" if session_token.public_id.blank?
  end

  def session_token_actor_matches?
    case resource
    when ::Operator
      session_token.respond_to?(:staff_id) && session_token.staff_id == resource.id
    when ::Visitor
      session_token.respond_to?(:visitor_id) && session_token.visitor_id == resource.id
    else
      session_token.respond_to?(:user_id) && session_token.user_id == resource.id
    end
  end

  def resource_type
    case resource
    when ::Operator then "operator"
    when ::Visitor then "visitor"
    else "client"
    end
  end
end
