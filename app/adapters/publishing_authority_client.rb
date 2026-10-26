# typed: false
# frozen_string_literal: true

# Edit RP client for the Publishing authority (R5-WU13, one.md section 6.4).
#
# Each call carries a fresh edit-org-ww private_key_jwt bound to the exact request URL and the
# Operator's current Access JWT; the authority decides with its own policy and Operations. Results
# are typed outcomes with allowlisted data, never model objects. Commands are not retried blindly:
# an indeterminate write is reported as :dependency and the RP re-reads before acting again.
class PublishingAuthorityClient
  Result =
    Data.define(:status, :data, :errors) do
      def ok? = status == :ok
    end

  CLIENT_ID = "edit-org-ww"
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 5
  # HTTP status -> outcome the Edit pages act on.
  STATUSES = {
    200 => :ok,
    201 => :ok,
    401 => :unauthorized,
    403 => :forbidden,
    404 => :not_found,
    422 => :unprocessable,
  }.freeze

  def initialize(surface:, audience:, access_token:)
    base_origin = Rails.configuration.x.boot_config.fetch(:hosts).base_for_resource_type("operator")
    @base = "#{base_origin}/api/v0/publishing/#{surface}/#{audience}"
    @access_token = access_token.to_s
  end

  public

  def entries(page:) = request(:get, "/entries", { page: })

  def entry(ref) = request(:get, "/entries/#{escape(ref)}")

  def create_entry(attributes) = request(:post, "/entries", { entry: attributes })

  def revise_entry(ref, attributes) = request(:patch, "/entries/#{escape(ref)}", { entry: attributes })

  def publish(ref, attributes) = request(:post, "/entries/#{escape(ref)}/publications", attributes)

  def end_publication(ref, publication_ref, attributes)
    request(:delete, "/entries/#{escape(ref)}/publications/#{escape(publication_ref)}", attributes)
  end

  def archive(ref, attributes) = request(:post, "/entries/#{escape(ref)}/archive", attributes)

  def unarchive(ref) = request(:delete, "/entries/#{escape(ref)}/archive")

  private

  attr_reader :base, :access_token

  def request(verb, path, params = {})
    return Result.new(status: :unauthorized, data: nil, errors: {}) if access_token.blank?

    url = "#{base}#{path}"
    assertion = OidcClientAssertionJwt.issue(client_id: CLIENT_ID, token_url: url)
    return Result.new(status: :dependency, data: nil, errors: {}) if assertion.blank?

    uri = URI.parse(url)
    connection = OutboundHttp::Connection.build(
      url: uri, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT, require_https: true,
    )
    headers = { "Authorization" => "Bearer #{access_token}",
                "X-Client-Assertion" => assertion,
                "Accept" => "application/json", }
    response =
      if verb == :get
        connection.get(uri, params, headers)
      else
        body = params.presence && Faraday::Utils.build_nested_query(params)
        connection.run_request(verb, uri, body, headers.merge("Content-Type" => "application/x-www-form-urlencoded"))
      end
    classify(response)
  rescue Faraday::Error, JSON::ParserError, URI::InvalidURIError, OutboundHttp::Connection::InsecureEndpointError
    Result.new(status: :dependency, data: nil, errors: {})
  end

  def classify(response)
    status = STATUSES.fetch(response.status.to_i, :dependency)
    body = JSON.parse(response.body.presence || "{}")
    return Result.new(status: :dependency, data: nil, errors: {}) unless body.is_a?(Hash)

    Result.new(status:, data: body, errors: body.fetch("errors", {}))
  end

  def escape(value) = ERB::Util.url_encode(value.to_s)
end
