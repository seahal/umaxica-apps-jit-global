# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::Identity::RecoverySecretsControllerTest < ActionDispatch::IntegrationTest
  fixtures :visitors

  setup do
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! @host
    @visitor = visitors(:reserved_visitor)
    @headers = as_visitor_headers(@visitor, host: @host)
  end

  test "dedicated route reveals a valid passcode once with private response headers" do
    reveal = IdentityOneTimeReveal.issue!(
      actor: @visitor,
      session_nonce: @visitor.public_id,
      value: %w(first-passcode second-passcode),
      purpose: "visitor.recovery_secret_credential",
    )
    token = VisitorToken.find_by!(public_id: @headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    token.update!(last_used_at: 10.minutes.ago)
    last_used_at = token.reload.last_used_at

    get base_com_identity_recovery_secret_url(token: reveal.token, ri: "jp", host: @host), headers: @headers

    assert_response :success
    page = Nokogiri::HTML(response.body).at_css("script[data-page='app']")
    props = JSON.parse(page.text).fetch("props")
    assert_equal %w(first-passcode second-passcode), props.fetch("passcodes")
    cache_control = response.headers.fetch("Cache-Control")
    %w(no-store no-cache must-revalidate private).each do |directive|
      assert_includes cache_control, directive
    end
    assert_equal "no-cache", response.headers.fetch("Pragma")
    assert_equal "0", response.headers.fetch("Expires")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
    assert_equal last_used_at, token.reload.last_used_at

    get base_com_identity_recovery_secret_url(token: reveal.token, ri: "jp", host: @host), headers: @headers

    assert_response :success
    page = Nokogiri::HTML(response.body).at_css("script[data-page='app']")
    props = JSON.parse(page.text).fetch("props")
    assert_empty props.fetch("passcodes")
    assert_predicate props.fetch("missing_message"), :present?
    cache_control = response.headers.fetch("Cache-Control")
    %w(no-store no-cache must-revalidate private).each do |directive|
      assert_includes cache_control, directive
    end
    assert_equal "no-cache", response.headers.fetch("Pragma")
    assert_equal "0", response.headers.fetch("Expires")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
    assert_equal last_used_at, token.reload.last_used_at
  end

  test "HEAD does not reveal or consume the one-time receipt" do
    reveal = IdentityOneTimeReveal.issue!(
      actor: @visitor,
      session_nonce: @visitor.public_id,
      value: ["head-protected-passcode"],
      purpose: "visitor.recovery_secret_credential",
    )
    path = base_com_identity_recovery_secret_path(token: reveal.token, ri: "jp")

    head path, headers: @headers

    assert_response :method_not_allowed
    assert_empty response.body

    get path, headers: @headers

    assert_response :success
    page = Nokogiri::HTML(response.body).at_css("script[data-page='app']")
    assert_equal ["head-protected-passcode"], JSON.parse(page.text).fetch("props").fetch("passcodes")
  end

  test "OPTIONS does not reveal or consume the one-time receipt" do
    reveal = IdentityOneTimeReveal.issue!(
      actor: @visitor,
      session_nonce: @visitor.public_id,
      value: ["options-protected-passcode"],
      purpose: "visitor.recovery_secret_credential",
    )
    path = base_com_identity_recovery_secret_path(token: reveal.token, ri: "jp")

    options path, headers: @headers

    assert_response :not_found
    refute_includes response.body, "options-protected-passcode"

    get path, headers: @headers

    assert_response :success
    page = Nokogiri::HTML(response.body).at_css("script[data-page='app']")
    assert_equal ["options-protected-passcode"], JSON.parse(page.text).fetch("props").fetch("passcodes")
  end

  test "a lost response does not make the consumed receipt available to a retry" do
    reveal = IdentityOneTimeReveal.issue!(
      actor: @visitor,
      session_nonce: @visitor.public_id,
      value: ["response-lost-passcode"],
      purpose: "visitor.recovery_secret_credential",
    )
    path = base_com_identity_recovery_secret_path(token: reveal.token, ri: "jp")
    request_headers = {
      "HTTP_AUTHORIZATION" => @headers.fetch("Authorization"),
      "HTTP_COOKIE" => @headers.fetch("Cookie"),
      "HTTP_X_TEST_CURRENT_RESOURCE" => @headers.fetch("X-TEST-CURRENT-RESOURCE"),
      "HTTP_X_TEST_SESSION_PUBLIC_ID" => @headers.fetch("X-TEST-SESSION-PUBLIC-ID"),
    }
    lost_response_app = lambda do |env|
      _status, _headers, body = Rails.application.call(env)
      body.close if body.respond_to?(:close)
      raise IOError, "simulated response loss after application completion"
    end

    assert_raises(IOError) do
      Rack::MockRequest.new(lost_response_app).get("https://#{@host}#{path}", request_headers)
    end

    get path, headers: @headers

    assert_response :success
    page = Nokogiri::HTML(response.body).at_css("script[data-page='app']")
    props = JSON.parse(page.text).fetch("props")
    assert_empty props.fetch("passcodes")
    assert_predicate props.fetch("missing_message"), :present?
  end

  test "dedicated route renders missing state for a malformed token" do
    get base_com_identity_recovery_secret_url(token: "malformed", ri: "jp", host: @host), headers: @headers

    assert_response :success
    page = Nokogiri::HTML(response.body).at_css("script[data-page='app']")
    props = JSON.parse(page.text).fetch("props")
    assert_empty props.fetch("passcodes")
    assert_predicate props.fetch("missing_message"), :present?
    cache_control = response.headers.fetch("Cache-Control")
    %w(no-store no-cache must-revalidate private).each do |directive|
      assert_includes cache_control, directive
    end
    assert_equal "no-cache", response.headers.fetch("Pragma")
    assert_equal "0", response.headers.fetch("Expires")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
  end

  test "dedicated route renders missing state for an expired token" do
    reveal = IdentityOneTimeReveal.issue!(
      actor: @visitor,
      session_nonce: @visitor.public_id,
      value: "expired-passcode",
      purpose: "visitor.recovery_secret_credential",
      expires_in: 1.second,
    )

    travel 2.seconds do
      get base_com_identity_recovery_secret_url(token: reveal.token, ri: "jp", host: @host), headers: @headers
    end

    assert_response :success
    page = Nokogiri::HTML(response.body).at_css("script[data-page='app']")
    props = JSON.parse(page.text).fetch("props")
    assert_empty props.fetch("passcodes")
    assert_predicate props.fetch("missing_message"), :present?
    cache_control = response.headers.fetch("Cache-Control")
    %w(no-store no-cache must-revalidate private).each do |directive|
      assert_includes cache_control, directive
    end
    assert_equal "no-cache", response.headers.fetch("Pragma")
    assert_equal "0", response.headers.fetch("Expires")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
  end
end
