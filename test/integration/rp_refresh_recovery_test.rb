# frozen_string_literal: true

require "test_helper"

# WU-10 (D-25, D-80, D-110): a Browser RP whose refresh credential is refused recovers through a new
# Authorization Code flow. A top-level navigation tries prompt=none once, without a click; every
# other representation answers without starting an authorization (browserless: 401).
class RpRefreshRecoveryTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  REFUSED = OidcOpTokenClient::Result.new(outcome: :refused, token_response: nil, error: "invalid_grant")
  INDETERMINATE = OidcOpTokenClient::Result.new(outcome: :indeterminate, token_response: nil, error: "timeout")
  DEPENDENCY = OidcOpTokenClient::Result.new(outcome: :dependency, token_response: nil, error: "server_error")

  setup do
    @host = ENV.fetch("PUBLIC_TECH_STAFF_URL")
    host! @host
    https!
  end

  test "a refused refresh on a navigation starts one prompt=none authorization and clears the credentials" do
    location = navigate_with_refresh_outcome(REFUSED)

    assert_response :see_other
    query = Rack::Utils.parse_query(URI.parse(authorization_url(location)).query)

    assert_equal "none", query.fetch("prompt")
    assert_equal "tech-org-ww", query.fetch("client_id")
    assert_equal "S256", query.fetch("code_challenge_method")
    assert_predicate query.fetch("state"), :present?
    assert_cookie_cleared OidcRpBrowserCredentialContract::REFRESH_COOKIE
  end

  test "an indeterminate refresh commit is treated as consumed and recovers through prompt=none" do
    location = navigate_with_refresh_outcome(INDETERMINATE)

    assert_response :see_other
    assert_equal "none", Rack::Utils.parse_query(URI.parse(authorization_url(location)).query).fetch("prompt")
    assert_cookie_cleared OidcRpBrowserCredentialContract::REFRESH_COOKIE
  end

  test "after the silent attempt cleared the credentials the next navigation takes the interactive entry" do
    navigate_with_refresh_outcome(REFUSED)

    OidcOpTokenClient.stub(:refresh, ->(**) { flunk("no credential is left to refresh") }) do
      get tech_org_dashboard_path(ri: "jp"), headers: { "Sec-Fetch-Mode" => "navigate" }
    end

    assert_response :redirect
    assert_equal "/sign", URI.parse(response.location).path
  end

  test "a non-navigation fetch with a refused refresh starts no authorization" do
    navigate_with_refresh_outcome(REFUSED, headers: { "Sec-Fetch-Mode" => "cors" })

    assert_response :redirect
    assert_equal "/sign", URI.parse(response.location).path
  end

  test "a browserless JSON request with a refused refresh answers 401" do
    navigate_with_refresh_outcome(REFUSED, headers: { "Accept" => "application/json" })

    assert_response :unauthorized
  end

  test "a dependency failure keeps the credentials and starts no authorization" do
    navigate_with_refresh_outcome(DEPENDENCY)

    assert_response :service_unavailable
    assert_nil Array(response.headers["Set-Cookie"]).join("\n")[
      /#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=;/o,
    ]
  end

  test "a local refresh reaches the OP token endpoint through the local back channel" do
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = "refresh-public-id.refresh-verifier"
    calls = []
    recorder =
      lambda do |**args|
        calls << args.slice(:token_url, :require_https)
        DEPENDENCY
      end
    OidcOpTokenClient.stub(:refresh, recorder) do
      get(tech_org_dashboard_path(ri: "jp"), headers: { "Sec-Fetch-Mode" => "navigate" })
    end
    public_endpoint = URI.parse(OidcIssuer.token_endpoint("operator").to_s)
    token_url = URI.parse(calls.sole.fetch(:token_url))

    assert_equal ["http", public_endpoint.host, Integer(ENV.fetch("PORT"), exception: false) || 3000,
                  public_endpoint.path, false,],
                 [token_url.scheme, token_url.host, token_url.port, token_url.path, calls.sole.fetch(:require_https)]
    assert_equal [503, I18n.t("errors.messages.temporarily_unavailable")], [response.status, response.body]
  end

  private

  def navigate_with_refresh_outcome(outcome, headers: { "Sec-Fetch-Mode" => "navigate" })
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = "refresh-public-id.refresh-verifier"
    OidcOpTokenClient.stub(:refresh, outcome) do
      get(tech_org_dashboard_path(ri: "jp"), headers:)
    end
    response.location
  end

  # The redirect is either the authorization endpoint itself or a Jump handoff whose signed `rt`
  # carries it; the authorization URL is read from whichever was returned.
  def authorization_url(location)
    uri = URI.parse(location)
    return location if uri.path.end_with?("/oauth/authorize")

    rt = Rack::Utils.parse_query(uri.query).fetch("rt")
    JSON.parse(Base64.urlsafe_decode64(rt.split(".").fetch(1))).fetch("url")
  end

  def assert_cookie_cleared(name)
    lines = Array(response.headers["Set-Cookie"]).flat_map { |value| value.to_s.split("\n") }
    cleared = lines.find { |line| line.start_with?("#{name}=") }

    assert cleared, "expected #{name} to be cleared"
    assert_match(/max-age=0|expires=Thu, 01 Jan 1970/i, cleared)
  end
end
