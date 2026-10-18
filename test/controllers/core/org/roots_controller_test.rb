# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Core::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  BRAND = ENV.fetch("BRAND_NAME").upcase

  test "renders a thin landing page" do
    host! ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost")
    get core_org_root_url(ri: "jp")

    assert_response :success
    assert_select "title", "#{BRAND} (ORG)"
    assert_equal "core/org/roots/index", inertia_component
    assert_nil inertia_props.fetch("title")
    assert_equal "Core Org", inertia_props.fetch("heading")
    assert_equal I18n.t("landing.thin_endpoint"), inertia_props.fetch("description")
  end

  test "root does not create preference state" do
    host! ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost")

    assert_no_difference("OrgPreference.count") do
      get core_org_root_url(ri: "jp")
    end

    assert_response :success
    assert_nil cookies[PreferenceCookieName.access(surface: :org)]
    assert_nil cookies[PreferenceCookieName.refresh(surface: :org)]
  end
end
