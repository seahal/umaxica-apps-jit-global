# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::Social::SessionsControllerTest < ActionDispatch::IntegrationTest
  counts_rate_limits!
  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    host! @host
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  teardown do
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "staff sign-in page offers the Entra ceremony entry point" do
    get "/sign/in", params: { ri: "jp" }

    assert_response :success
    entra = inertia_props.fetch("methods").find { |method| method.fetch("key") == "entra" }

    assert_equal "provider", entra.fetch("kind")
    assert_equal auth_org_social_entra_session_path(ri: "jp"), entra.fetch("href")
  end

  # The tenant is fixed in configuration, so the ceremony starts on the press
  # alone -- the same shape as the app surface's Google and Apple buttons.
  test "POST hands the ceremony off with a 307" do
    post auth_org_social_entra_session_path(ri: "jp")

    assert_response :temporary_redirect
    assert_equal "http://#{@host}/social/entra", response.location
  end

  test "POST refuses a provider that does not belong to this surface" do
    post "/social/google/session", params: {}

    assert_response :not_found
  end

  test "GET new renders the ceremony form and asks the operator for nothing" do
    get new_auth_org_social_entra_session_path(ri: "jp")

    assert_response :success
    assert_equal "auth/org/social/sessions/new", inertia_component
    assert_equal "/social/entra", inertia_props.fetch("form").fetch("action")
    # The tenant is fixed in configuration, so the page asks the operator for nothing.
    assert_select "input[type=?]", "text", count: 0
  end

  test "GET new renders a form and cannot start the ceremony on its own" do
    # A GET carries no CSRF token, so a GET that started a ceremony would be
    # login CSRF (CVE-2015-9284) - the reason the app surface has no GET entry
    # at all. This GET is a landing page only: it renders the button and sends
    # nothing to Microsoft until a person presses it. Only #create hands off.
    get new_auth_org_social_entra_session_path(ri: "jp")

    assert_response :success
    assert_no_match(
      /\.submit\(\)/, response.body,
      "the landing page must not submit itself: a person has to press the button",
    )
  end

  test "the ceremony start endpoint is not reachable by GET" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{@host}/social/entra/session", method: :get)
    end
  end

  test "POST fails closed and starts no ceremony when the Entra provider is unavailable" do
    disabled = Object.new
    disabled.define_singleton_method(:start_decision) { |**|
      ExternalAuthentication::AvailabilityDecision.new(
        state: :disabled, source: "test", configuration_version: nil, reason_code: "test_disabled",
        incident_id: nil, observed_at: Time.current,
      )
    }

    ExternalAuthentication::ProviderAvailabilityFactory.stub(:current, disabled) do
      post auth_org_social_entra_session_path(ri: "jp")
    end

    assert_response :service_unavailable
    assert_equal I18n.t("sign.org.authentication.entra.errors.provider_unavailable"),
                 inertia_props.fetch("unavailable_notice")
    assert_nil inertia_props["form"]
  end

  test "POST is rate limited per client address" do
    21.times do
      post auth_org_social_entra_session_path(ri: "jp")
    end

    assert_response :too_many_requests
  end

  test "route recognizes the ceremony start endpoint" do
    route = Rails.application.routes.recognize_path("http://#{@host}/social/entra/session", method: :post)

    assert_equal "auth/org/social/sessions", route[:controller]
    assert_equal "create", route[:action]
    assert_equal "entra", route[:provider]
  end
end
