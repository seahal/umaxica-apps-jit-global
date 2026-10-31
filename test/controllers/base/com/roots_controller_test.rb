# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::RootsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
  end

  test "renders the anonymous preference entry" do
    get base_com_root_url(ri: "jp")

    assert_response :success
    assert_equal "base/com/roots/index", inertia_component
    assert_equal "Base Com", inertia_props.fetch("heading")
    assert_nil inertia_props["sign_in"]
    assert_nil inertia_props["sign_up"]
    assert_equal [base_com_preference_path(ri: "jp")], inertia_props.fetch("links").pluck("href")
  end

  test "anonymous root and preference screens read only corporate settings and chronicle databases" do
    databases = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
      connection = payload[:connection]
      databases << connection.pool.db_config.name if connection
    end

    get base_com_root_url(ri: "jp")

    assert_response :success
    get base_com_preference_path(ri: "jp")
    assert_response :success
    get edit_base_com_preference_theme_path(ri: "jp")
    assert_response :success
    assert_empty databases.uniq - %w(com_setting com_setting_replica chronicle chronicle_replica)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "keeps extra request context on the anonymous root" do
    get base_com_root_url(ri: "jp", ct: "dr", lx: "en", tz: "asia/tokyo")

    assert_response :success
    assert_nil response.location
  end

  test "region does not change the anonymous entry copy for the same language" do
    %w(en ja).each do |locale|
      copy = %w(jp us).map do |region|
        browser = open_session
        browser.host! ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
        browser.https!
        browser.get base_com_root_path(ri: region, lx: locale)

        assert_equal 200, browser.response.status
        page = browser.response.parsed_body.at_css("script[data-page='app']")
        props = JSON.parse(page.text).fetch("props")
        [props.fetch("description"), props.fetch("links").first.fetch("label")]
      end

      assert_equal copy.first, copy.last, locale
      assert_equal I18n.t("landing.thin_endpoint", locale: locale), copy.first.first
    end
  end

  test "canonicalizes an unknown region to the default" do
    get base_com_root_url(ri: "xx")

    assert_response :found
    assert_redirected_to base_com_root_url(ri: "jp")
  end

  test "canonicalizes a missing region to the default" do
    get "/"

    assert_response :found
    assert_redirected_to base_com_root_url(ri: "jp")
  end

  test "an injected RP credential cookie does not change the anonymous result" do
    headers = {
      "Cookie" => [
        "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=injected-access-token",
        "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=injected-refresh-token",
      ].join("; "),
    }

    get base_com_root_url(ri: "jp"), headers: headers

    assert_response :success
    assert_equal "base/com/roots/index", inertia_component
    assert_equal "Base Com", inertia_props.fetch("heading")
  end

  test "the removed signed-in dashboard and sign-in routes are not routable" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/dashboard", method: :get, host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"))
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/sign", method: :get, host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"))
    end
  end
end
