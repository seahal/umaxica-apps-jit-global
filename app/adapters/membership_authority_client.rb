# typed: false
# frozen_string_literal: true

# Base Self-RP client for the account / organization / membership owner (R5-WU15, same approved
# pattern as R5-WU14). Same transport and outcome rules as AvatarAuthorityClient.
class MembershipAuthorityClient
  Result = AvatarAuthorityClient::Result
  CLIENTS = AvatarAuthorityClient::CLIENTS
  STATUSES = AvatarAuthorityClient::STATUSES
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 5

  def initialize(surface:, access_token:, persona:)
    @client_id, resource_type = CLIENTS.fetch(surface.to_s)
    @base = "#{OidcIssuer.for_resource_type(resource_type)}/api/v0/membership/#{surface}"
    @access_token = access_token.to_s
    @persona = persona.to_s
  end

  public

  def accounts = request(:get, "/accounts")

  def account(ref) = request(:get, "/accounts/#{escape(ref)}")

  def organizations = request(:get, "/organizations")

  def organization(ref) = request(:get, "/organizations/#{escape(ref)}")

  def memberships(org_ref, page: 1) = request(:get, "/organizations/#{escape(org_ref)}/memberships", { page: })

  def membership(org_ref, id) = request(:get, "/organizations/#{escape(org_ref)}/memberships/#{escape(id)}")

  def authorization(org_ref, rule, id: nil)
    params = { rule: }
    params[:id] = id if id
    request(:post, "/organizations/#{escape(org_ref)}/memberships/authorization", params)
  end

  private

  attr_reader :client_id, :base, :access_token, :persona

  def request(verb, path, params = {}, idempotency_key: nil)
    return Result.new(status: :unauthorized, data: nil, errors: {}) if access_token.blank?

    url = "#{base}#{path}"
    assertion = OidcClientAssertionJwt.issue(client_id:, token_url: url)
    return Result.new(status: :dependency, data: nil, errors: {}) if assertion.blank?

    uri = URI.parse(url)
    connection = OutboundHttp::Connection.build(
      url: uri, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT, require_https: true,
    )
    headers = { "Authorization" => "Bearer #{access_token}",
                "X-Client-Assertion" => assertion,
                "Accept" => "application/json", }
    headers["Idempotency-Key"] = idempotency_key if idempotency_key
    params = params.merge(persona:)
    response =
      if verb == :get
        connection.get(uri, params, headers)
      else
        connection.run_request(
          verb, uri, Faraday::Utils.build_nested_query(params),
          headers.merge("Content-Type" => "application/x-www-form-urlencoded"),
        )
      end
    body = response.body.present? ? JSON.parse(response.body) : {}
    return Result.new(status: :dependency, data: nil, errors: {}) unless body.is_a?(Hash)

    Result.new(status: STATUSES.fetch(response.status.to_i, :dependency), data: body, errors: body.fetch("errors", {}))
  rescue Faraday::Error, JSON::ParserError, URI::InvalidURIError, OutboundHttp::Connection::InsecureEndpointError
    Result.new(status: :dependency, data: nil, errors: {})
  end

  def escape(value) = ERB::Util.url_encode(value.to_s)
end
