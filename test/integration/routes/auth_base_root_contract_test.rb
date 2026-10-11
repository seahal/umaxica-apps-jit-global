# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthBaseRootContractTest < ActionDispatch::IntegrationTest
  FACES = {
    "auth.app.localhost" => "/sign/in",
    "auth.com.localhost" => "/sign/in",
    "auth.org.localhost" => "/sign/in",
    "base.app.localhost" => "/",
    "base.com.localhost" => "/",
    "base.org.localhost" => "/",
  }.freeze

  test "six Auth/Base roots are routable and retired paths are not" do
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

    assert_includes AuthBoundaryAuthorityMap.retired_browser_paths, "/dashboard"
    assert_includes AuthBoundaryAuthorityMap.retired_browser_paths, "/lobby"
  end

  test "Auth and Base root controllers exist for each face" do
    %w(App Com Org).each do |face|
      assert Object.const_defined?("Auth::#{face}::RootsController")
      assert Object.const_defined?("Base::#{face}::RootsController")
      assert_not Object.const_defined?("Auth::#{face}::DashboardsController")
      assert_not Object.const_defined?("Base::#{face}::DashboardsController")
      assert_not Object.const_defined?("Base::#{face}::LobbiesController")
    end
  end
end
