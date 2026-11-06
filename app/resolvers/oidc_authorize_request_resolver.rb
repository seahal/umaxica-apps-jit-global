# typed: false
# frozen_string_literal: true

class OidcAuthorizeRequestResolver < ApplicationService
  # An error found after `client_id` and `redirect_uri` were validated: returned to the registered
  # `redirect_uri` (RFC 6749 4.1.2.1, OIDC Core 3.1.2.6, D-147).
  class RequestError < ArgumentError
    attr_reader :error

    def initialize(message, error: "invalid_request")
      super(message)
      @error = error
    end
  end

  class InvalidScope < RequestError
    def initialize(message) = super(message, error: "invalid_scope")
  end

  class UnmetAuthenticationRequirements < RequestError
    def initialize(message) = super(message, error: "unmet_authentication_requirements")
  end

  # Unsupported or combined `prompt` values: a direct HTTP 400 from the OP, never redirected
  # (Prompt Create 1.0 4.1, D-148).
  class UnsupportedPrompt < ArgumentError; end

  SUPPORTED_PROMPTS = %w(login none create).freeze
  PROMPTS_BY_RESOURCE_TYPE = {
    "client" => %w(none login create),
    "operator" => %w(none login),
  }.freeze
  # RFC 7636 4.2: an S256 challenge is BASE64URL(SHA-256) without padding.
  CODE_CHALLENGE_PATTERN = /\A[A-Za-z0-9_-]{43}\z/
  STEP_UP_ACR = "https://visa.umaxica.app/acr/reauthentication".freeze
  STEP_UP_SCOPE = "oidc_authorization".freeze
  STEP_UP_RETURN_TO = "/oauth/authorize".freeze
  STEP_UP_CLAIMS = JSON.generate(
    "id_token" => {
      "acr" => { "essential" => true, "value" => STEP_UP_ACR },
      "auth_time" => { "essential" => true },
    },
  ).freeze

  ValidatedRequest = Data.define(:client, :scope, :prompt, :max_age, :step_up_requested)

  class << self
    public

    def prompt_values_supported(resource_type)
      PROMPTS_BY_RESOURCE_TYPE.fetch(resource_type.to_s)
    end

    def normalize_prompt(value)
      tokens = value.to_s.split
      return nil if tokens.empty?
      return tokens.first if tokens.one? && SUPPORTED_PROMPTS.include?(tokens.first)

      raise ArgumentError, "prompt is not supported"
    end

    def normalize_max_age(value)
      return nil if value.blank?

      normalized =
        if value.is_a?(Integer)
          value
        elsif value.to_s.match?(/\A\d+\z/)
          value.to_i
        else
          raise ArgumentError
        end
      raise ArgumentError, "max_age must be a non-negative integer" if normalized.negative?

      normalized
    rescue ArgumentError, TypeError
      raise ArgumentError, "max_age must be a non-negative integer"
    end
  end

  def initialize(params:, resource:, resource_type: nil)
    super()
    @params = params
    @resource = resource
    @given_resource_type = resource_type
  end

  # Order matters (D-147): only after `client_id` and `redirect_uri` are valid may an error be
  # redirected to the RP.
  def call
    raise ArgumentError, "client_id is required" if client_id.blank?

    client = find_client!
    raise ArgumentError, "redirect_uri is required" if redirect_uri.blank?

    validate_redirect_uri!
    validate_response_type!
    raise RequestError, "scope must include openid" unless scope_includes_openid?

    scope = validate_scope_allowlist!(client)
    prompt = validate_prompt!
    validate_code_challenge!
    max_age = normalize_max_age!
    validate_state_and_nonce!
    validate_resource!
    step_up_requested = validate_claims_request!
    ValidatedRequest.new(
      client: client, scope: scope, prompt: prompt, max_age: max_age, step_up_requested: step_up_requested,
    )
  end

  private

  attr_reader :params, :resource, :given_resource_type

  def validate_response_type!
    raise RequestError, "response_type is required" if params[:response_type].blank?
    return if params[:response_type] == "code"

    raise RequestError.new("response_type must be 'code'", error: "unsupported_response_type")
  end

  def validate_prompt!
    tokens = params[:prompt].to_s.split
    return nil if tokens.empty?
    raise UnsupportedPrompt, "prompt must be a single value" unless tokens.one?
    return tokens.first if self.class.prompt_values_supported(resource_type).include?(tokens.first)

    raise UnsupportedPrompt, "prompt value is not supported"
  end

  def validate_code_challenge!
    raise RequestError, "code_challenge is required" if params[:code_challenge].blank?
    raise RequestError, "code_challenge_method must be 'S256'" unless params[:code_challenge_method] == "S256"
    return if params[:code_challenge].to_s.match?(CODE_CHALLENGE_PATTERN)

    raise RequestError, "code_challenge must be 43 base64url characters"
  end

  def normalize_max_age!
    self.class.normalize_max_age(params[:max_age])
  rescue ArgumentError => e
    raise RequestError, e.message
  end

  def validate_state_and_nonce!
    raise RequestError, "state is required" if params[:state].blank?
    raise RequestError, "nonce is required" if params[:nonce].blank?
  end

  def validate_resource!
    return if resource.blank?

    raise RequestError.new("resource is not active", error: "access_denied") unless resource&.active?
  end

  def validate_claims_request!
    claims_present = params.key?(:claims)
    acr_values_present = params.key?(:acr_values)
    return false unless claims_present || acr_values_present

    claims = parse_claims_request!(params[:claims]) if claims_present
    acr_values = parse_acr_values!(params[:acr_values]) if acr_values_present
    if claims_present && acr_values_present && acr_values != [STEP_UP_ACR]
      raise RequestError, "acr_values conflicts with the essential acr claim"
    end
    if claims_present && claims == :unsupported
      raise UnmetAuthenticationRequirements, "requested authentication class is not supported"
    end
    raise RequestError, "acr_values requires the canonical claims request" unless claims_present
    raise RequestError, "claims must request the canonical step-up class" unless claims == :step_up

    true
  end

  def parse_claims_request!(value)
    raise RequestError, "claims must be a JSON object" unless value.is_a?(String) && value.present?

    parsed = JSON.parse(value)
    return :step_up if parsed == JSON.parse(STEP_UP_CLAIMS)
    return :unsupported if unsupported_essential_acr_claim?(parsed)

    raise RequestError, "claims must request essential acr and auth_time"
  rescue JSON::ParserError
    raise RequestError, "claims must be valid JSON"
  end

  def unsupported_essential_acr_claim?(claims)
    return false unless claims.is_a?(Hash)

    id_token = claims["id_token"]
    return false unless id_token.is_a?(Hash)

    acr = id_token["acr"]
    auth_time = id_token["auth_time"]
    return false unless acr.is_a?(Hash) && acr["essential"] == true && auth_time == { "essential" => true }

    requested_value = acr["value"]
    requested_value.is_a?(String) && requested_value.present? && requested_value != STEP_UP_ACR
  end

  def parse_acr_values!(value)
    raise RequestError, "acr_values must be a non-empty string" unless value.is_a?(String) && value.present?

    values = value.split
    raise RequestError, "acr_values must contain one value" unless values.one?

    values
  end

  def validate_scope_allowlist!(client)
    requested_scopes = scope_tokens
    invalid_scopes = requested_scopes - client.allowed_scopes

    raise InvalidScope, "scope is not allowed for client #{client.client_id}" if invalid_scopes.any?

    requested_scopes.join(" ")
  end

  def find_client!
    OidcClientRegistry.find!(client_id)
  end

  def validate_redirect_uri!
    return if OidcClientRegistry.valid_redirect_uri?(client_id, redirect_uri, resource_type: resource_type)

    raise OidcClientRegistry::InvalidRedirectUri,
          "redirect_uri is not registered for client #{client_id} in realm #{resource_type}"
  end

  def resource_type
    return OidcSubject.normalize_resource_type(given_resource_type) unless given_resource_type.nil?

    case resource
    when ::Operator then "operator"
    when ::Client then "client"
    else raise ArgumentError, "unsupported OIDC resource"
    end
  end

  def client_id
    params[:client_id]
  end

  def redirect_uri
    params[:redirect_uri]
  end

  def scope_includes_openid?
    scope_tokens.include?("openid")
  end

  def scope_tokens
    params[:scope].to_s.split
  end
end
