# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class DbscRegistrationEndpointWiringTest < ActiveSupport::TestCase
  test "sign dbsc controllers use shared registration endpoint concern" do
    assert_includes Auth::App::Edge::V0::Token::DbscController, SignDbscRegistrationEndpoint
    assert_includes Auth::Org::Edge::V0::Token::DbscController, SignDbscRegistrationEndpoint
  end

  # The core realm, not base: `base/*/edge/v0/dbsc` was a rename leftover that no route named, so
  # asserting the wiring against it guarded a class no request could reach. The routed preference
  # DBSC endpoint is `/api/v0/preferences/dbsc`, backed conservatively by the existing Core classes.
  test "core dbsc controllers use shared preference registration endpoint concern" do
    assert_includes Core::App::Api::V0::Preferences::DbscController, PreferenceDbscRegistrationEndpoint
    assert_includes Core::Org::Api::V0::Preferences::DbscController, PreferenceDbscRegistrationEndpoint
    assert_includes Core::Com::Api::V0::Preferences::DbscController, PreferenceDbscRegistrationEndpoint
  end

  # The wiring above is only meaningful if these are the classes the router actually reaches.
  test "every dbsc controller asserted here is one the router mounts" do
    {
      "auth/app/edge/v0/token/dbsc" => "create",
      "auth/org/edge/v0/token/dbsc" => "create",
      "core/app/api/v0/preferences/dbsc" => "create",
      "core/com/api/v0/preferences/dbsc" => "create",
      "core/org/api/v0/preferences/dbsc" => "create",
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
      Auth::App::Edge::V0::Token::DbscController,
      Auth::Org::Edge::V0::Token::DbscController,
    ]
    preference_controllers = [
      Core::App::Api::V0::Preferences::DbscController,
      Core::Org::Api::V0::Preferences::DbscController,
      Core::Com::Api::V0::Preferences::DbscController,
    ]

    (sign_controllers + preference_controllers).each do |controller|
      assert_not_includes controller.instance_methods(false), :handle_registration
      assert_not_includes controller.instance_methods(false), :handle_bound_cookie_refresh
      assert_not_includes controller.instance_methods(false), :dbsc_cookie_attributes_string
    end
  end
end
