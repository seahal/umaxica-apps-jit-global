# frozen_string_literal: true

require "test_helper"

# AT-048 / AT-052: the Tech sign-in start issues a code + PKCE S256 + state + nonce request only from
# a CSRF-protected POST on the Tech host, keeps return targets on Tech, refuses foreign hosts and is
# never cached.
class TechOrgSignInTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_TECH_STAFF_URL")
    host! @host
    https!
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
  end

  test "a protected POST starts an authorization request with code, PKCE S256, state and nonce" do
    authorize_params = start_sign_in(pt: "/dashboard")

    assert_equal "code", authorize_params.fetch("response_type")
    assert_equal "tech-org", authorize_params.fetch("client_id")
    assert_equal "S256", authorize_params.fetch("code_challenge_method")
    assert_predicate authorize_params.fetch("code_challenge"), :present?
    assert_predicate authorize_params.fetch("state"), :present?
    assert_predicate authorize_params.fetch("nonce"), :present?
    assert_equal @host, URI.parse(authorize_params.fetch("redirect_uri")).host
    flow = session.fetch(OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY).fetch(authorize_params.fetch("state"))

    assert_not_equal flow.fetch("code_verifier"), authorize_params.fetch("code_challenge")
  end

  test "an external or protocol-relative return target is never carried into the flow" do
    %w(https://attacker.invalid/steal //attacker.invalid/steal).each do |target|
      authorize_params = start_sign_in(pt: target)
      flow = session.fetch(OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY).fetch(authorize_params.fetch("state"))

      assert_not_includes flow.to_json, "attacker.invalid"
      assert_not_includes response.location, "attacker.invalid"
    end
  end

  test "a request for a foreign Host is not served by Tech" do
    host! "attacker.invalid"
    get tech_org_sign_show_path(ri: "jp")

    assert_not_equal 200, response.status
    assert_not_includes response.body.to_s, "tech-org"
  end

  test "an untrusted forwarded host does not change the callback target" do
    authorize_params = start_sign_in(pt: "/dashboard", headers: { "X-Forwarded-Host" => "attacker.invalid" })

    assert_equal @host, URI.parse(authorize_params.fetch("redirect_uri")).host
  end

  test "sign-in responses are not cacheable" do
    get tech_org_sign_show_path(ri: "jp")

    assert_includes response.headers.fetch("Cache-Control"), "no-store"

    start_sign_in(pt: "/dashboard")

    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end

  test "the sign-in start does not log the state, nonce or code verifier" do
    output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output)
    authorize_params = start_sign_in(pt: "/dashboard")
    flow = session.fetch(OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY).fetch(authorize_params.fetch("state"))

    assert_not_includes output.string, flow.fetch("code_verifier")
    assert_not_includes output.string, authorize_params.fetch("nonce")
  ensure
    Rails.logger = original_logger
  end

  private

  def start_sign_in(pt:, headers: {})
    get(tech_org_sign_show_path(ri: "jp"))
    csrf_token = css_select('input[name="authenticity_token"]').first["value"]
    post(
      tech_org_sign_create_path(ri: "jp"),
      params: { authenticity_token: csrf_token, pt: pt },
      headers: { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin" }.merge(headers),
    )

    assert_response :see_other
    Rack::Utils.parse_nested_query(URI.parse(response.location).query)
  end
end
