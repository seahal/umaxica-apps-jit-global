# frozen_string_literal: true

require "test_helper"

class VisaRootsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "each Visa host serves its own public root without issuing cookies" do
    {
      "visa.umaxica.app" => ["visa/app/roots", "Visa App"],
      "visa.umaxica.com" => ["visa/com/roots", "Visa Com"],
      "visa.umaxica.org" => ["visa/org/roots", "Visa Org"],
      "visa.app.localhost" => ["visa/app/roots", "Visa App"],
      "visa.com.localhost" => ["visa/com/roots", "Visa Com"],
      "visa.org.localhost" => ["visa/org/roots", "Visa Org"],
    }.each do |host, (controller, heading)|
      host! host
      get "/"

      assert_response :found
      assert_equal "jp", Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("ri")
      assert_nil response.headers["Set-Cookie"]
      follow_redirect!

      assert_response :ok
      assert_equal controller, request.path_parameters[:controller]
      assert_equal "text/html", response.media_type
      assert_select "title", heading
      assert_select "main h1", heading
      assert_select "header .ui-landing__brand", text: /VISA/
      assert_select "main .ui-landing__intro p", text: I18n.t("landing.thin_endpoint")
      assert_select "main a.ui-button", text: I18n.t("landing.sign_in")
      assert_select "footer nav a", text: I18n.t("ui_presentation.navigation.preferences")
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_nil response.headers["Set-Cookie"]

      head "/", params: { ri: "jp" }

      assert_response :ok
      assert_empty response.body
      assert_nil response.headers["Set-Cookie"]
    end
  end

  test "landing destinations use the matching Base origin and preserve supplied region" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    {
      "visa.app.localhost" => hosts.base_service,
      "visa.com.localhost" => hosts.base_corporate,
      "visa.org.localhost" => hosts.base_staff,
    }.each do |host, origin|
      host! host
      get "/", params: { ri: "us" }

      assert_response :ok
      assert_select "main a.ui-button[href='#{origin}/sign?ri=us']", count: 1
      assert_select "footer nav a[href='#{origin}/preference?ri=us']", count: 1
      assert_select "form", count: 0
      assert_nil response.headers["Set-Cookie"]
    end
  end

  test "landing honors the display theme cookie without writing cookies" do
    host! "visa.com.localhost"
    cookies[:ct] = "dark"
    get "/", params: { ri: "jp" }

    assert_response :ok
    assert_select "html[data-theme=dark]"
    assert_select "a.ui-skip-link[href='#main']"
    assert_select "main#main[tabindex='-1']"
    assert_nil response.headers["Set-Cookie"]
  end

  test "landing copy is available in both supported languages" do
    host! "visa.app.localhost"
    %i(en ja).each do |locale|
      I18n.with_locale(locale) do
        get "/", params: { ri: "jp" }

        assert_response :ok
        assert_select "html[lang='#{locale}']"
        assert_select "main a.ui-button", text: I18n.t("landing.sign_in")
        assert_select "main .ui-landing__intro p", text: I18n.t("landing.thin_endpoint")
        assert_nil response.headers["Set-Cookie"]
      end
    end
  end

  test "look-alike Visa hosts remain unknown" do
    %w(visa.umaxica.app.example visa.umaxica.com.example visa.umaxica.org.example).each do |host|
      host! host
      get "/"

      assert_response :not_found
      assert_equal "unknown_host", response.parsed_body.fetch("error")
    end
  end
end
