# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Core::App::RootsControllerTest < ActionDispatch::IntegrationTest
  BRAND = ENV.fetch("BRAND_NAME").upcase

  test "renders a thin landing page" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"))
    get core_app_root_url(ri: "jp")

    assert_response :success
    assert_select "title", "#{BRAND} (APP)"
    assert_equal "core/app/roots/index", inertia_component
    assert_nil inertia_props.fetch("title")
    assert_equal "Core App", inertia_props.fetch("heading")
    assert_equal I18n.t("landing.thin_endpoint"), inertia_props.fetch("description")
  end

  test "root does not create preference state" do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"))

    assert_no_difference("AppPreference.count") do
      get core_app_root_url(ri: "jp")
    end

    assert_response :success
    assert_nil cookies[PreferenceCookieName.access(surface: :app)]
    assert_nil cookies[PreferenceCookieName.refresh(surface: :app)]
  end
end
