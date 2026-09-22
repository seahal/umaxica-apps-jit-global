# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthBaseAuthorityBoundaryTest < ActiveSupport::TestCase
  AUTH_APPLICATION_CONTROLLERS = [
    Auth::App::ApplicationController,
    Auth::Com::ApplicationController,
    Auth::Org::ApplicationController,
  ].freeze

  BASE_APPLICATION_CONTROLLERS = [
    Base::App::ApplicationController,
    Base::Com::ApplicationController,
    Base::Org::ApplicationController,
  ].freeze

  AUTH_SIGN_OUT_CONTROLLERS = [
    Auth::App::Sign::OutsController,
    Auth::Com::Sign::OutsController,
    Auth::Org::Sign::OutsController,
  ].freeze

  test "Auth and Base application controllers do not act as browser RPs" do
    (AUTH_APPLICATION_CONTROLLERS + BASE_APPLICATION_CONTROLLERS).each do |controller|
      assert_not_includes controller.ancestors, OidcSsoInitiator, controller.name
      assert_not controller.private_method_defined?(:oidc_client_id), controller.name
    end
  end

  test "Auth sign-out controllers do not act as OIDC RPs" do
    AUTH_SIGN_OUT_CONTROLLERS.each do |controller|
      assert_not_includes controller.ancestors, OidcRpLogoutLauncher, controller.name
      assert_not controller.private_method_defined?(:oidc_client_id), controller.name
    end
  end
end
