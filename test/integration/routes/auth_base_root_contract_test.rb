# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthBaseRootContractTest < ActionDispatch::IntegrationTest
  FACES = {
    "auth.app.localhost" => "/sign/in",
    "auth.org.localhost" => "/sign/in",
    "base.app.localhost" => "/",
    "base.com.localhost" => "/",
    "base.org.localhost" => "/",
  }.freeze

  test "five Auth/Base roots are routable and authority-specific retired paths remain recorded" do
    FACES.each_key do |_host|
      assert_nothing_raised do
        Rails.application.routes.recognize_path("/", method: :get)
      end
    end

    %w(/dashboard /lobby /sign/out/complete).each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(path, method: :get)
      end
    end

    assert_includes AuthBoundaryAuthorityMap.retired_auth_browser_paths, "/dashboard"
    assert_not_includes AuthBoundaryAuthorityMap.retired_browser_paths, "/dashboard"
    assert_includes AuthBoundaryAuthorityMap.retired_browser_paths, "/lobby"
  end

  test "Auth and Base root controllers exist for each remaining face" do
    # two.md WU-3: the corporate Auth host owns no surface controller at all.
    %w(App Org).each do |face|
      assert Object.const_defined?("Auth::#{face}::RootsController")
      assert_not Object.const_defined?("Auth::#{face}::DashboardsController")
    end
    %w(App Com Org).each do |face|
      assert Object.const_defined?("Base::#{face}::RootsController")
      assert_not Object.const_defined?("Base::#{face}::DashboardsController")
      assert_not Object.const_defined?("Base::#{face}::LobbiesController")
    end
  end
end
