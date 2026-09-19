# typed: false
# frozen_string_literal: true

class OidcAuthorizationCodeIssuer < ApplicationService
  def initialize(client:, params:, resource:, session_token:, auth_method: nil, acr: nil,
                 authentication_event_at: nil,
                 store: Valkey::AuthState::AuthorizationCodeStore.new)
    super()
    @client = client
    @params = params
    @resource = resource
    @session_token = session_token
    @auth_method = auth_method
    @acr = acr
    @authentication_event_at = authentication_event_at
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
      acr: acr,
      amr: auth_method,
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

  attr_reader :client, :params, :resource, :session_token, :auth_method, :acr, :authentication_event_at

  def required_authentication_event_at
    return authentication_event_at if authentication_event_at.present?

    raise ArgumentError, "authentication event time is required"
  end

  def validate_session_token!
    raise ArgumentError, "session_token is required" if session_token.blank?
    raise ArgumentError, "session token actor mismatch" unless session_token_actor_matches?
    raise ArgumentError,
          "session token is inactive" unless session_token.respond_to?(:currently_usable?) &&
            session_token.currently_usable?
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
