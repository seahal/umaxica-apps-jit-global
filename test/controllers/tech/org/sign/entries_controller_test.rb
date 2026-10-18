# typed: false
# frozen_string_literal: true

require "test_helper"

class Tech::Org::Sign::EntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_TECH_STAFF_URL")
    host! @host
  end

  test "GET and HEAD sign entry issue no OIDC flow" do
    get tech_org_sign_show_path(ri: "jp")

    assert_response :success
    assert_nil session[OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY]

    head tech_org_sign_show_path(ri: "jp")

    assert_response :success
    assert_nil session[OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY]
  end

  test "JSON sign POST rejects missing and invalid CSRF tokens before flow creation" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    [nil, "invalid-token"].each do |token|
      post(
        tech_org_sign_create_path(ri: "jp"),
        params: { authenticity_token: token },
        headers: { "Origin" => "http://#{@host}", "Sec-Fetch-Site" => "same-origin" },
        as: :json,
      )

      assert_response :forbidden
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_nil session[OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY]
    end
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "same-origin POST without an authenticity token is refused before flow creation" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    post(
      tech_org_sign_create_path,
      headers: {
        "Origin" => "http://#{@host}",
        "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_response :unprocessable_content
    assert_nil session[OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY]
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "POST without Fetch Metadata or an authenticity token is refused before flow creation" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    post(tech_org_sign_create_path(ri: "jp"), headers: { "Origin" => "http://#{@host}" })

    assert_response :unprocessable_content
    assert_nil session[OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY]
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "POST with a valid authenticity token starts the Tech authorization flow" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    get(tech_org_sign_show_path(ri: "jp"))
    authenticity_token = css_select('input[name="authenticity_token"]').first["value"]
    post(
      tech_org_sign_create_path(ri: "jp"),
      params: { authenticity_token: authenticity_token },
      headers: {
        "Origin" => "http://#{@host}",
        "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_response :see_other
    assert_predicate session[OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY], :present?
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "POST with an invalid token is refused before flow creation" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    post(
      tech_org_sign_create_path(ri: "jp"),
      params: { authenticity_token: "invalid" },
      headers: {
        "Origin" => "http://#{@host}",
        "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_response :unprocessable_content
    assert_nil session[OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY]
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "valid token from a mismatched origin is refused before flow creation" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    get(tech_org_sign_show_path(ri: "jp"))
    authenticity_token = css_select('input[name="authenticity_token"]').first["value"]
    post(
      tech_org_sign_create_path(ri: "jp"),
      params: { authenticity_token: authenticity_token },
      headers: {
        "Origin" => "https://attacker.example",
        "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_response :unprocessable_content
    assert_nil session[OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY]
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
