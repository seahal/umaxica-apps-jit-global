# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class DbscRegistrationEndpointWiringTest < ActiveSupport::TestCase
  test "sign dbsc controllers use shared registration endpoint concern" do
    assert_includes Visa::App::Edge::V0::Token::DbscController, SignDbscRegistrationEndpoint
    assert_includes Visa::Org::Edge::V0::Token::DbscController, SignDbscRegistrationEndpoint
  end

  test "every dbsc controller asserted here is one the router mounts" do
    {
      "visa/app/edge/v0/token/dbsc" => "create",
      "visa/org/edge/v0/token/dbsc" => "create",
    }.each do |controller, action|
      mounted =
        Rails.application.routes.routes.any? do |route|
          route.defaults[:controller] == controller && route.defaults[:action] == action
        end

      assert mounted, "#{controller}##{action} is asserted on but no route mounts it"
    end
  end

  test "controllers do not redefine dbsc registration internals locally" do
    sign_controllers = [
      Visa::App::Edge::V0::Token::DbscController,
      Visa::Org::Edge::V0::Token::DbscController,
    ]
    sign_controllers.each do |controller|
      assert_not_includes controller.instance_methods(false), :handle_registration
      assert_not_includes controller.instance_methods(false), :handle_bound_cookie_refresh
      assert_not_includes controller.instance_methods(false), :dbsc_cookie_attributes_string
    end
  end
end
