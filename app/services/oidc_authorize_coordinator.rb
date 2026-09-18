# typed: false
# frozen_string_literal: true

class OidcAuthorizeCoordinator < ApplicationService
  Result =
    Data.define(:success, :redirect_url, :redirect_uri, :error, :error_description) do
      def success? = success
    end

  def initialize(params:, resource:, session_token:, auth_method: nil, acr: nil, authentication_event_at: nil)
    super()
    @params = params
    @resource = resource
    @session_token = session_token
    @auth_method = auth_method
    @acr = acr
    @authentication_event_at = authentication_event_at
  end

  def call
    validation = validate_request!
    code_record = issue_authorization_code!(validation)
    build_success_redirect(code_record)
  rescue OidcClientRegistry::ClientNotFound => e
    failure("unauthorized_client", e.message)
  rescue OidcAuthorizeRequestResolver::InvalidScope => e
    failure("invalid_scope", e.message)
  rescue OidcClientRegistry::InvalidRedirectUri, ArgumentError => e
    failure("invalid_request", e.message)
  rescue ActiveRecord::RecordInvalid, Umaxica::Valkey::Unavailable, Umaxica::Valkey::SerializationError,
         Umaxica::Valkey::OperationError => e
    failure("server_error", e.message)
  end

  class << self
    public

    # Builds an authorization response redirect to an already validated RP redirect_uri.
    # Callers must validate the client and redirect_uri first (OidcAuthorizeRequestResolver).
    def rp_redirect_url(redirect_uri:, resource_type:, response_params:)
      uri = URI.parse(redirect_uri)
      normalize_default_port!(uri)
      query_params = URI.decode_www_form(uri.query || "") + response_params
      # RFC 9207: identify the issuing authorization server in the response so a
      # client registered against more than one AS cannot be tricked into sending
      # the code to the wrong one (RFC 9700 section 4.4.2, mix-up attack). The same
      # RP is registered against all three surface issuers with an identical
      # callback path, so the per-AS-URI alternative holds only by host here.
      query_params << ["iss", OidcIssuer.for_resource_type(resource_type)]
      uri.query = URI.encode_www_form(query_params)
      uri.to_s
    end

    # OIDC Core 1.0 section 3.1.2.6: authentication errors such as login_required are
    # returned to the RP redirect_uri with the original state, not rendered locally.
    def error_redirect_url(redirect_uri:, resource_type:, error:, state: nil)
      response_params = [["error", error]]
      response_params << ["state", state] if state.present?
      rp_redirect_url(redirect_uri: redirect_uri, resource_type: resource_type, response_params: response_params)
    end

    private

    def normalize_default_port!(uri)
      default_port =
        case uri.scheme
        when "https" then 443
        when "http" then 80
        end

      uri.port = nil if default_port.present? && uri.port == default_port
    end
  end

  private

  attr_reader :params, :resource, :session_token, :auth_method, :acr, :authentication_event_at

  def validate_request!
    OidcAuthorizeRequestResolver.call(params: params, resource: resource)
  end

  def issue_authorization_code!(client)
    OidcAuthorizationCodeIssuer.call(
      client: client.client,
      params: params.merge(scope: client.scope),
      resource: resource,
      session_token: session_token,
      auth_method: auth_method,
      acr: acr,
      authentication_event_at: authentication_event_at,
    )
  end

  def build_success_redirect(code_record)
    response_params = [["code", code_record.code]]
    response_params << ["state", code_record.state] if code_record.state.present?

    Result.new(
      success: true,
      redirect_url: self.class.rp_redirect_url(
        redirect_uri: code_record.redirect_uri,
        resource_type: code_record.resource_type,
        response_params: response_params,
      ),
      redirect_uri: code_record.redirect_uri, error: nil, error_description: nil,
    )
  end

  def failure(error, description)
    Result.new(success: false, redirect_url: nil, redirect_uri: nil, error: error, error_description: description)
  end
end
