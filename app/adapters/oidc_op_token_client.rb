# typed: false
# frozen_string_literal: true

require "timeout"

# RP-side client for the OP token endpoint over public HTTPS (R5-WU05, one.md section 6.4).
#
# An RP never calls OidcTokenExchangeCoordinator in-process: it presents a fresh endpoint-bound
# private_key_jwt assertion to the OP's registered token endpoint, exactly like an external client.
# Results are classified so callers can tell a definitive refusal (clear credentials) from a
# dependency failure (keep cookies, retry later) and from an indeterminate commit (the OP may have
# rotated the Refresh credential; D-25 has no replay of a lost response, so the RP recovers through a
# new Authorization Code flow, never a blind retry).
class OidcOpTokenClient
  # success        - 200 with a JSON token response.
  # refused        - definitive OAuth refusal (400/401 with an OAuth error, e.g. invalid_grant).
  # dependency     - the request was not processed: connection refused, DNS, 5xx, 429, 503.
  # invalid_remote - the OP answered with something that is not a valid protocol response
  #                  (redirect, corrupt success body, unexpected status).
  # indeterminate  - the request may have committed but no response arrived (read timeout).
  OUTCOMES = %i(success refused dependency invalid_remote indeterminate).freeze
  # access_denied is the OP's refusal for a client whose actor lacks a required capability (Tech).
  REFUSAL_ERRORS = %w(invalid_grant invalid_client invalid_request unauthorized_client unsupported_grant_type
                      invalid_scope access_denied).freeze

  Result =
    Data.define(:outcome, :token_response, :error) do
      def success? = outcome == :success
    end

  INITIAL_REQUEST_BUDGET = 2.0
  class RequestDeadlineExceeded < StandardError; end

  class << self
    public

    def authorization_code(client_id:, token_url:, code:, redirect_uri:, code_verifier:, require_https: true,
                           deadline: nil)
      new(client_id:, token_url:, require_https:, deadline:, request_budget: INITIAL_REQUEST_BUDGET).call(
        grant_type: "authorization_code", code:, redirect_uri:, code_verifier:,
      )
    end

    def refresh(client_id:, token_url:, refresh_token:, require_https: true, deadline: nil)
      new(client_id:, token_url:, require_https:, deadline:, request_budget: INITIAL_REQUEST_BUDGET).call(
        grant_type: "refresh_token", refresh_token:,
      )
    end
  end

  def initialize(client_id:, token_url:, require_https:, request_budget:, deadline:)
    @client_id = client_id
    @token_url = token_url
    @require_https = require_https
    @deadline = [monotonic_now + request_budget, deadline].compact.min
  end

  public

  def call(**grant_params)
    return result(:indeterminate, error: "timeout") if monotonic_now >= deadline

    # The assertion audience is this exact token endpoint, so it cannot be replayed elsewhere.
    assertion = OidcClientAssertionJwt.issue(client_id: client_id, token_url: token_url)
    return result(:invalid_remote, error: "client_assertion_unavailable") if assertion.blank?

    uri = URI.parse(token_url)
    remaining = deadline - monotonic_now
    return result(:indeterminate, error: "timeout") unless remaining.positive?

    connection = OutboundHttp::Connection.build(
      url: uri, open_timeout: remaining, read_timeout: remaining, write_timeout: remaining,
      require_https: require_https,
    )
    params = grant_params.merge(
      client_id: client_id,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: assertion,
    )
    remaining = deadline - monotonic_now
    return result(:indeterminate, error: "timeout") unless remaining.positive?

    # Interrupt only the disposable HTTP connection, never a caller's DB transaction or locks.
    # Per-phase socket timeouts alone allow a trickling response to outlive the request budget.
    response = Timeout.timeout(remaining, RequestDeadlineExceeded) { connection.post(uri, params) }
    classified = classify(response)
    return result(:indeterminate, error: "timeout") if monotonic_now >= deadline

    classified
  rescue Faraday::TimeoutError, RequestDeadlineExceeded
    # Transmission may have started; the credential may already be rotated, so it is never resent.
    result(:indeterminate, error: "timeout")
  rescue Faraday::Error
    result(:dependency, error: "transport_failure")
  rescue OutboundHttp::Connection::InsecureEndpointError, URI::InvalidURIError
    result(:invalid_remote, error: "invalid_endpoint")
  end

  private

  attr_reader :client_id, :token_url, :require_https, :deadline

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def classify(response)
    status = response.status.to_i
    return result(:dependency, error: "server_error") if status >= 500 || status == 429
    # Redirects are never followed: a token endpoint must answer directly.
    return result(:invalid_remote, error: "unexpected_redirect") if status.between?(300, 399)

    body = parse_body(response.body)
    return result(:invalid_remote, error: "invalid_response") if body.nil?

    if status == 200
      return result(:invalid_remote, error: "invalid_response") unless
        body[:access_token].is_a?(String) && body[:access_token].present?

      return Result.new(outcome: :success, token_response: body, error: nil)
    end
    if [400, 401, 403].include?(status) && REFUSAL_ERRORS.include?(body[:error].to_s)
      return result(:refused, error: body[:error].to_s)
    end

    result(:invalid_remote, error: "unexpected_status")
  end

  def parse_body(raw)
    parsed = JSON.parse(raw.presence || "")
    parsed.is_a?(Hash) ? parsed.with_indifferent_access : nil
  rescue JSON::ParserError
    nil
  end

  def result(outcome, error:)
    Result.new(outcome:, token_response: nil, error:)
  end
end
