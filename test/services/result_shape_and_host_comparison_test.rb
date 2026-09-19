# typed: false
# frozen_string_literal: true

require "test_helper"

# Result shapes and host comparisons that other code reads to decide an HTTP
# status or whether a redirect target is this surface's own. Each has an arm that
# has to answer rather than raise, and each wrong answer is either a status the
# client cannot act on or a host comparison that accepts somebody else's.
class ResultShapeAndHostComparisonTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "only the declared terminal sign-in statuses map to an HTTP status" do
    {
      session_limit_hard_reject: :forbidden,
      guardrail_blocked: :forbidden,
      login_forbidden: :forbidden,
      credential_failed: :unauthorized,
      invalid_request: :bad_request,
    }.each do |status, http_status|
      assert SignInStateMachine.terminal_status?(status), "#{status} must be terminal"
      assert_equal http_status, SignInStateMachine.http_status_for(status), status.to_s
      assert SignInStateMachine.terminal_status?(status.to_s), "#{status} must be terminal as a string too"
    end

    assert_not SignInStateMachine.terminal_status?(:advanced)
    assert_raises(KeyError) { SignInStateMachine.http_status_for(:advanced) }
  end

  # The result is read both by attribute and by key, and #fetch is the strict
  # form: a key that resolved to nothing is a caller error rather than a nil that
  # travels on into a token payload.
  test "a refresh result answers by key and refuses a key that resolved to nothing" do
    result = AcmeRefreshTokenIssuer::Result.new(
      success: true, token: :token, refresh_token: "raw", previous_token: nil, reason: nil,
    )

    assert_predicate result, :success?
    assert_equal "raw", result[:refresh_token]
    assert_equal "raw", result.fetch(:refresh_token)

    error = assert_raises(KeyError) { result.fetch(:previous_token) }

    assert_match(/key not found: :previous_token/, error.message)
  end

  # A configured host that cannot be parsed as an authority is compared verbatim
  # rather than treated as matching everything.
  test "an unparsable configured host is compared verbatim rather than accepted" do
    request = OidcEndSessionRequest.allocate

    assert request.send(:host_matches?, "www.umaxica.app", "www.umaxica.app")
    assert_not request.send(:host_matches?, "www.umaxica.app", "evil.example.com")
    assert request.send(:host_matches?, "[oops", "[oops")
    assert_not request.send(:host_matches?, "www.umaxica.app", "[oops")
  end

  # A redirect URI carrying its scheme's default port is normalised so it
  # compares equal to the registered one, which never carries it.
  test "a default port is dropped from a redirect URI and a non-default one kept" do
    redirect =
      lambda do |uri|
        URI.parse(
          OidcAuthorizeCoordinator.rp_redirect_url(redirect_uri: uri, resource_type: "client", response_params: []),
        )
      end

    https = redirect.call("https://rp.example.test:443/callback")

    assert_equal "https://rp.example.test/callback", https.to_s.split("?").first

    http = redirect.call("http://rp.example.test:80/callback")

    assert_equal "http://rp.example.test/callback", http.to_s.split("?").first

    explicit = redirect.call("https://rp.example.test:8443/callback")

    assert_equal "https://rp.example.test:8443/callback", explicit.to_s.split("?").first
  end
end
